# centreon_consolidate_alerts

## The goal
This script is helpfull to generate reports on Centreon alerts. <br> <br>

## Technical specification
This script will read data from the 3 tables centeron_storage.logs + downtimes + acknownledgements in the time slot [--start => --end]. The script will feed a new custom table [your_database].Alert where each entry in the table represents a Centreon alert. The conf file is used to populate the connection information for the database centreon_storage and your database for the Alert table. <br>
<b>NOTE:</b> The --conf option is mandatory

## Requirements

  - Accessibility to Centreon database
  - a new database with the SQL table Alert (see the file Alert.sql)
  - Perl
  - mysql client

## Tested with...

Centreon 2.5.4

## Options
```erb
centreon_consolidate_alerts.pl --conf <conf_file.conf> : conf file
       [--start <DD-MM-YYYY>|<DD/MM>] default : start and end date is the last day
       [--end <DD-MM-YYYY>|<DD/MM>] default : start and end date is the last day
       [--verbose] [--debug]
```

## Utilisation 

Launch the script (if you want data about the October month in the table Alert) :
```erb
# ./centreon_consolidate_alerts.pl --start 01/10 --end 01/11  --verbose --conf database_info.conf > centreon_consolidate_alerts.log
```

## Performance


## Examples 

TOP10 unavailability hosts with downtime supported (<b>if your ping service is called 'ping'</b>) :
```erb
SELECT host_name, service_description, service_id, SUM( interpreted_duration ) AS tps_indispo
FROM Alert
WHERE service_description LIKE 'ping'
GROUP BY service_id
ORDER BY tps_indispo DESC
LIMIT 10


```

