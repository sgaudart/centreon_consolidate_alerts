#!/usr/bin/perl
#======================================================================
# Auteur : sgaudart@capensis.fr
# Date   : 14/09/2016
# But    : This script is designed to populate the SQL table <your_database>.Alert
#          from the table centreon_storage.logs + downtimes + acknownledgements
# INPUT : 
#          start time + end time (time range)
# OUTPUT :
#          populate the table Alert
#
#======================================================================
#   Date       Version   Auteur    Commentaires
# 14/09/2016   1         SGA       initial version
# 17/09/2016   2         SGA       add function ExecQuery
# 21/09/2016   3         SGA       add option --debug (in addition of --verbose)
# 22/09/2016   4         SGA       add function SearchDowntimes
# 23/09/2016   5         SGA       add calculation of the raw_duration + downtime_occurrence
# 26/09/2016   6         SGA       add function FinalizeAlert + fix bug chr ' in sql query
# 27/09/2016   7         SGA       add function CalculateInterpretedDuration
# 30/09/2016   8         SGA       improve the function CalculateInterpretedDuration
# 04/10/2016   9         SGA       add function SearchAcknownledgement
# 11/10/2016  10         SGA       fix bug : Argument "NULL" isn't numeric in numeric gt (>)
# 14/10/2016  11         SGA       add option --conf
# 24/10/2016  12         SGA       change fonction ChangeDateToUnixTime + yesterday default
#======================================================================

use strict;
use warnings;
use Getopt::Long;
use Time::Local;

my $start=""; # option --start
my $end=""; # option --end
my $start_epoch=0;
my $end_epoch=0;
my $conf_file="";

my $verbose;
my $debug;
my $help;

GetOptions (
"start=s" => \$start, # integer
"end=s" => \$end, # string
"conf=s" => \$conf_file, # string
"verbose" => \$verbose, # flag
"debug" => \$debug, # flag for the debug
"help" => \$help) # flag
or die("Error in command line arguments\n");

my $line;
my ($hostCentstorage,$dbnameCentstorage,$userCentstorage,$passCentstorage); # connection to centreon_storage
our ($hostAlert,$dbnameAlert,$userAlert,$passAlert); # connection to the new database with table Alert

my $sqlline=0; # line counter
my ($la_id,$la_endtime,$la_status); # Last Alert field

my ($log_id,$host_id,$host_name,$service_id,$service_description,$status,$output,$ctime,$type); # log fields

our %downtime; # hash list for downtimes ex: $downtime{service_id}{$downtime_id}{start|end}
my ($downtime_id,$author,$comment_data,$actual_start_time,$actual_end_time,$end_time); # downtime fields
my $downtimes_list;

our %ack; # hash list for acknowledgement ex: $ack{service_id}{$ack_id}{entry_time}
my ($ack_id, $entry_time); # ack fields

###############################
# HELP
###############################

if (($help) || ($conf_file eq ''))
{
	print "$0 v.12
Sebastien Gaudart <sgaudart\@capensis.fr>

Ce script va lire les données des 3 tables centreon_storage.logs + downtimes + acknownledgements
dans le créneau horaire [--start => --end]. Le script va alimenter la table <your_database>.Alert
où chaque entrée de la table représente une alerte Centreon. Le fichier de conf permet de renseigner
les informations de connexion pour la database centreon_storage et votre database pour la table Alert.
NOTE: l'option --conf est obligatoire
	
Utilisation :
 $0 --conf <conf_file.conf> : conf file
       [--start <DD-MM-YYYY>] default : start & end date is the last day
       [--end <DD-MM-YYYY>] default : start & end date is the last day
       [--verbose] [--debug]\n";
	
	exit;
}

###############################
# PROCESSING $start + $end => unix time
###############################

if (($start eq "") || ($end eq ""))
{
	# --start or --end not defined => default : yesterday
	my @now = localtime(time);
	my $end_day=$now[3];
	my $end_month=$now[4]+1;
	my $year = $now[5]+1900;
	$end="$end_day-$end_month-$year";

	$end_epoch = ChangeDateToUnixTime($end);
	$start_epoch = $end_epoch - 86400;
}
else
{
	$start_epoch = ChangeDateToUnixTime($start);
	$end_epoch = ChangeDateToUnixTime($end);
}

print "[DEBUG] start=$start => start_epoch=$start_epoch\n" if $debug;
print "[DEBUG] end=$end => end_epoch=$end_epoch\n" if $debug;

###############################
# READING THE CONF FILE
###############################

open (CONFFD, "$conf_file") or die "Can't open configuration file  : $conf_file\n" ; # reading
while (<CONFFD>)
{
	$line=$_;
	chomp($line); # delete the carriage return
	if ($line =~ /^hostCentstorage(.*)$/) { $hostCentstorage = $1; $hostCentstorage =~ s/[ \t]+//; }
	if ($line =~ /^dbnameCentstorage(.*)$/) { $dbnameCentstorage = $1; $dbnameCentstorage =~ s/[ \t]+//; }
	if ($line =~ /^userCentstorage(.*)$/) { $userCentstorage = $1; $userCentstorage =~ s/[ \t]+//; }
	if ($line =~ /^passCentstorage(.*)$/) { $passCentstorage = $1; $passCentstorage =~ s/[ \t]+//; }
	
	if ($line =~ /^hostAlert(.*)$/) { $hostAlert = $1; $hostAlert =~ s/[ \t]+//; }
	if ($line =~ /^dbnameAlert(.*)$/) { $dbnameAlert = $1; $dbnameAlert =~ s/[ \t]+//; }
	if ($line =~ /^userAlert(.*)$/) { $userAlert = $1; $userAlert =~ s/[ \t]+//; }
	if ($line =~ /^passAlert(.*)$/) { $passAlert = $1; $passAlert =~ s/[ \t]+//; }
}
close CONFFD;

my $sqlprefix = "mysql --batch -h $hostCentstorage -u $userCentstorage -p$passCentstorage -D $dbnameCentstorage -e";

###################################################
# SQL REQUEST FOR DOWNTIMES > FILE downtimes
###################################################

#my $sqlrequest = "SELECT downtime_id,host_id,service_id,author,comment_data,actual_start_time,actual_end_time,end_time FROM downtimes WHERE (actual_start_time>$start_epoch and actual_start_time<$end_epoch) OR (actual_end_time>$start_epoch and actual_end_time<$end_epoch)";
my $sqlrequest = "SELECT downtime_id,host_id,service_id,author,comment_data,actual_start_time,actual_end_time FROM downtimes WHERE (actual_start_time>$start_epoch and actual_start_time<$end_epoch) OR (actual_end_time>$start_epoch and actual_end_time<$end_epoch) OR (actual_start_time<$start_epoch and actual_end_time>$end_epoch)";
print "[DEBUG] sqlrequest = $sqlprefix $sqlrequest\n" if $debug;
system "$sqlprefix \"$sqlrequest;\" > downtimes";

###############################
$sqlline=0;
open (DOWNFD, "downtimes") or die "Can't open file downtimes\n" ; # reading the downtimes file
while (<DOWNFD>)
{
	$sqlline++; # line counter
	if ($sqlline eq 1) { next; } # next if the first line
	
	$line=$_;
	chomp($line); # delete the carriage return
	($downtime_id,$host_id,$service_id,$author,$comment_data,$actual_start_time,$actual_end_time,$end_time) = split('\t', $line);
	$downtime{$service_id}{$downtime_id}{start} = $actual_start_time;
	if ($actual_end_time ne 'NULL')
	{
		$downtime{$service_id}{$downtime_id}{end} = $actual_end_time;
	}
	else
	{
		$downtime{$service_id}{$downtime_id}{end} = $end_time;
	}
}
close DOWNFD;

###################################################
# SQL REQUEST FOR ACK > FILE acknownledgements
###################################################

$sqlrequest = "SELECT acknowledgement_id,host_id,service_id,author,comment_data,entry_time FROM acknowledgements WHERE (entry_time>$start_epoch and entry_time<$end_epoch)";
print "[DEBUG] sqlrequest = $sqlprefix $sqlrequest\n" if $debug;
system "$sqlprefix \"$sqlrequest;\" > acknownledgements";

###############################
$sqlline=0;
open (ACKFD, "acknownledgements") or die "Can't open file acknownledgements\n" ; # reading the ack file
while (<ACKFD>)
{
	$sqlline++; # line counter
	if ($sqlline eq 1) { next; } # next if the first line
	
	$line=$_;
	chomp($line); # delete the carriage return
	($ack_id,$host_id,$service_id,$author,$comment_data,$entry_time) = split('\t', $line);
	$ack{$service_id}{$ack_id}{entry_time} = $entry_time;
	$ack{$service_id}{$ack_id}{host_id} = $host_id;
	$ack{$service_id}{$ack_id}{author} = $author;
	$ack{$service_id}{$ack_id}{comment} = $comment_data;
}
close ACKFD;


###################################################
# SQL REQUEST FOR LOGS > FILE logs
###################################################

$sqlrequest = "SELECT log_id,host_id,host_name,service_id,service_description,status,output,ctime,type FROM logs WHERE ctime>$start_epoch and ctime<$end_epoch and output is not NULL and msg_type = 0 ORDER BY log_id";
print "[DEBUG] sqlrequest = $sqlprefix $sqlrequest\n" if $debug;
system "$sqlprefix \"$sqlrequest;\" > logs";

###############################
# MAIN : PARSE LOGS FILE
###############################
$sqlline=0;
open (LOGSFD, "logs") or die "Can't open file logs\n" ; # reading the logs file
while (<LOGSFD>)
{
	$sqlline++; # line counter
	if ($sqlline eq 1) { next; } # next if the first line
	
	$line=$_;
	chomp($line); # delete the carriage return
	($log_id,$host_id,$host_name,$service_id,$service_description,$status,$output,$ctime,$type) = split('\t', $line);
	print "$log_id " if $verbose;
	$la_id = ExecQuery("SELECT MAX(id) FROM Alert WHERE host_id = $host_id and service_id = $service_id"); # recherche de la dernière alerte
	print "[$la_id] " if $debug;
	$la_endtime = ExecQuery("SELECT end_time FROM Alert WHERE id = $la_id");
	
	if ($status eq 0) # OK => alert finished
	{
		if ($la_id ne 'NULL' && $la_endtime eq 'NULL') # last alarm exist & not finished
		{
			# last alarm exist & not finished => update field end_time
			FinalizeAlert($la_id,$la_endtime);
		} # do nothing else because we don't know the beginning of the alert => so no duration
	}
	else # WARNING|CRITICAL|UNKNOWN
	{
		$output =~ s/'/ /g; # replace ' => space (fix bug V6)
		$output =~ s/"/ /g; # replace " => space (fix bug V6)
		if ($la_id eq 'NULL' || ($la_id ne 'NULL' && $la_endtime ne 'NULL')) # cas : nouvelle alerte
		{
			if ($type eq 0)
			{
				# CASE NEW SOFT ALERT
				ExecQuery("INSERT INTO Alert (id,host_id,host_name,service_id,service_description,status,output,soft_start_time) VALUES ($log_id,$host_id,\"$host_name\",$service_id,\"$service_description\",$status,\"$output\",$ctime)");
				print "> NEW #$log_id soft" if $verbose;
			}
			else # rare
			{
				# CASE NEW HARD ALERT
				ExecQuery("INSERT INTO Alert (id,host_id,host_name,service_id,service_description,status,output,hard_start_time) VALUES ($log_id,$host_id,\"$host_name\",$service_id,\"$service_description\",$status,\"$output\",$ctime)");
				print "> NEW #$log_id hard" if $verbose;
			}
		}
		else # alerte en cours
		{
			if ($type eq 1)
			{
				# traitement du cas : couple identique mais changement de status
				$la_status = ExecQuery("SELECT status FROM Alert WHERE id = $la_id");
				
				if ($status eq $la_status)
				{
					# MAJ du champ hard_start_time
					ExecQuery("UPDATE Alert SET hard_start_time = $ctime WHERE id = $la_id");
					print "> UPD #$la_id hard" if $verbose;
				}
				else # il s'agit d'une nouvelle alerte mais status différent
				{
					# MAJ à champ end_time pour la dernière alerte dans la table Alert
					FinalizeAlert($la_id,$la_endtime);
					
					# création d'une nouvelle alerte dans le status actuel ($status)
					ExecQuery("INSERT INTO Alert (id,host_id,host_name,service_id,service_description,status,output,hard_start_time) VALUES ($log_id,$host_id,\"$host_name\",$service_id,\"$service_description\",$status,\"$output\",$ctime)");
					print " + NEW #$log_id hard" if $verbose;
				}
			}
		}
		
	} # fin detection log W|C|U

	print "\n" if $verbose;

} # fin boucle sur les logs
close LOGSFD; # this is the end my friend


#############  FONCTIONS  #################

sub ChangeDateToUnixTime # anything like date => unix time (in sec)
{
	my $date = $_[0]; # 1 ARG : date to transform
	my $epoch="";
	if ($date =~ /^[0-9]+$/)
	{
		$epoch=$date;
	}
	else
	{
		$date =~ s/\./-/g; # global substitution "." => "-"
		$date =~ s/\//-/g; # global substitution "/" => "-"
		
		my ($day, $month, $year)=split("-",$date);
		if (!(defined $year)) # oups I forgot the year
		{
			my @now = localtime(time);
			$year = $now[5]+1900;
		}
		$epoch = timelocal(0,0,0,$day,$month-1,$year);
	}
	return $epoch;
}

# Execute sql query into the new database with table Alert
sub ExecQuery
{
	my $sqlquery = $_[0]; # ARG1 : requete SQL
	my $sqlline=0;
	
	my $sqlprefix = "mysql --batch -h $hostAlert -u $userAlert -p$passAlert -D $dbnameAlert -e";
	
	print "[DEBUG] sqlquery=$sqlquery\n" if $debug;
	open (OUTFD, "$sqlprefix '$sqlquery' |");
	while (<OUTFD>)
	{
		$sqlline++;
		if ($sqlline eq 1) { next; } # next if the first line
		$line=$_;
		chomp($line); # delete the carriage return
	}
	close OUTFD;

	return $line;
}

sub SearchDowntimes # retourne une liste de downtime_id qui impacte un service (service_id) et sur une période de tps
{
	my $downtime_id;
	my $result="";
	
	my $service_id = $_[0]; # ARG1 : service_id
	my $alarm_start = $_[1]; # ARG2 : alert start
	my $alarm_end = $_[2]; # ARG3s : alert end
	
	if ($service_id ne 'NULL')
	{
		foreach $downtime_id (sort keys %{ $downtime{$service_id} })
		{
			if (($downtime{$service_id}{$downtime_id}{start} > $alarm_start && $downtime{$service_id}{$downtime_id}{start} < $alarm_end) || ($downtime{$service_id}{$downtime_id}{end} > $alarm_start && $downtime{$service_id}{$downtime_id}{end} < $alarm_end))
			{
				$result=$downtime_id . " " . $result;
			}
			
			if ($downtime{$service_id}{$downtime_id}{start} < $alarm_start && $downtime{$service_id}{$downtime_id}{end} > $alarm_end)
			{
				# le downtime recouvre completement l'alerte
				$result=$downtime_id . " " . $result;
			}
		}
		chop($result); # del the last chr
		return $result;
	}
	else
	{
		return '';
	}
	
}

sub FinalizeAlert # permet de stocker le end_time + chercher les downtimes + calcul de downtime_occurence (+ recherche d'un ack)
{
	my $la_id = $_[0]; # ARG1 : last alert id
	my $end_time = $_[1]; # ARG1 : end_time
	
	my $downtimes_list="";
	my @down_list;
	my $la_occurrence;
	my $interpreted_duration;
	my $ack_id;
	my $la_rawduration;
	# MAJ à champ end_time pour la dernière alerte dans la table Alert
	ExecQuery("UPDATE Alert SET end_time = $ctime WHERE id = $la_id");
	print "> END #$la_id" if $verbose;
	
	# we guess the beginning of the alerte => soft_start_time or hard_start_time ?
	my $la_time = ExecQuery("SELECT soft_start_time,hard_start_time,end_time FROM Alert WHERE id = $la_id");
	my ($la_softstart, $la_hardtime, $la_endtime) = split(' ',$la_time);
	if ($la_softstart eq 'NULL')
	{
		# alerte HARD
		$la_rawduration=$la_endtime-$la_hardtime;
		$downtimes_list = SearchDowntimes($service_id,$la_hardtime,$la_endtime); # input : service_id,alert start,alert end
		@down_list = split (' ',$downtimes_list);
		$la_occurrence = $#down_list+1;
		$interpreted_duration=CalculateInterpretedDuration($service_id,$la_hardtime,$la_endtime,$la_occurrence,$downtimes_list);
		$ack_id=SearchAcknownledgement($service_id,$la_hardtime,$la_endtime);
	}
	else
	{
		# alerte SOFT
		$la_rawduration=$la_endtime-$la_softstart;
		$downtimes_list = SearchDowntimes($service_id,$la_softstart,$la_endtime); # input : service_id,alert start,alert end
		@down_list = split (' ',$downtimes_list);
		$la_occurrence = $#down_list+1;
		$interpreted_duration=CalculateInterpretedDuration($service_id,$la_softstart,$la_endtime,$la_occurrence,$downtimes_list);
		$ack_id=SearchAcknownledgement($service_id,$la_softstart,$la_endtime);
	}

	ExecQuery("UPDATE Alert SET raw_duration=$la_rawduration, acknowledgement_id=$ack_id, downtime_id=\"$downtimes_list\", downtime_occurrence=$la_occurrence, interpreted_duration=$interpreted_duration WHERE id = $la_id");
    print " [downtime_id=$downtimes_list]" if $debug;
	print " [ack_id=$ack_id]" if $debug;
}


sub CalculateInterpretedDuration
{
	my $svc_id = $_[0]; # ARG1 : servive_id
	my $start = $_[1]; # ARG2 : alert start 
	my $end = $_[2]; # ARG3 : alert end
	my $occurrence = $_[3]; # ARG4: downtime occurrence
	my $down_id = $_[4]; # ARG4 : downtime id
	my $interpreted = 0; # result value
	my $min;
	my $max=0;
	
	if ($occurrence eq 0) # no downtime
	{
		$interpreted=$end-$start;
	}
	else
	{
		# we have downtime => we search the min and the max of the downtime timerange
		my @list_id = split (' ',$down_id);
		$min = $downtime{$svc_id}{$list_id[0]}{start};
		foreach my $id (@list_id) # search the min and max for the downtimes
		{
			if ($downtime{$svc_id}{$id}{start} < $min)
			{
				$min=$downtime{$svc_id}{$id}{start};
			}
			
			if ($downtime{$svc_id}{$id}{end} > $max)
			{	
				$max=$downtime{$svc_id}{$id}{end};
			}
		}
		
		# CASE 1 (total coverage)
		if (($min < $start) && ($max > $end))
		{
			$interpreted=0;
		}
		
		# CASE 2 (end of the alert is detected)
		if (($min < $start) && ($max < $end))
		{
			$interpreted=$end-$max;
		}
		
		# CASE 3 (beginning of the alert is detected)
		if (($min > $start) && ($max > $end))
		{
			$interpreted=$min-$start;
		}
		
		# CASE 4 (beginning AND the end of the alert is detected)
		if (($min > $start) && ($max < $end))
		{
			$interpreted=($end-$start)-($max-$min);
		}
	}
	
	return $interpreted;

}


sub SearchAcknownledgement # retourne un acknownledgement_id qui impacte un service (service_id) et sur une période de tps
{
	my $ack_id;
	my $result="NULL";
	
	my $service_id = $_[0]; # ARG1 : service_id
	my $alarm_start = $_[1]; # ARG2 : alert start
	my $alarm_end = $_[2]; # ARG3s : alert end
	
	if ($service_id ne 'NULL')
	{
		foreach $ack_id (sort keys %{ $ack{$service_id} })
		{	
			if ($ack{$service_id}{$ack_id}{entry_time} > $alarm_start && $ack{$service_id}{$ack_id}{entry_time} < $alarm_end)
			{
				$result=$ack_id; # ack is detected
			}
		}
		#chop($result); # del the last chr
		return $result;
	}
	else
	{
		return 'NULL';
	}
	
}
