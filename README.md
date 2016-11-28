# centreon_consolidate_alerts

## The goal
This script is helpfull to generate reports on Centreon alerts. <br> <br>

## Technical specification
This script will read data from the 3 tables centeron_storage.logs + downtimes + acknownledgements in the time slot [--start => --end].
<br>

The script will feed a [new custom table [your_database].Alert](https://github.com/sgaudart/centreon_consolidate_alerts/blob/master/Alert.sql) where each entry in the table represents a Centreon alert. See info in the attached documentation [table_Alert.pdf](https://github.com/sgaudart/centreon_consolidate_alerts/blob/master/table_Alert.pdf).
<br>

The conf file is used to populate the connection information for the database centreon_storage and your database for the Alert table. <br>
**NOTE:** The --conf option is mandatory

## Requirements

  - Accessibility to Centreon database
  - a new database with the SQL table Alert (see the file [Alert.sql](https://github.com/sgaudart/centreon_consolidate_alerts/blob/master/Alert.sql))
  - Perl
  - mysql client

## Tested with...

Centreon 2.5.4

## Roadmap

In construction...

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

Example : for 780 alerts/day => 1 mn/day of work for the script to feed the table Alert.

## Examples 

TOP10 unavailability hosts with downtime supported (**if your ping service is called 'ping'**) :
```erb
SELECT host_name, service_description, service_id, SUM( interpreted_duration ) AS tps_indispo
FROM Alert
WHERE service_description LIKE 'ping'
GROUP BY service_id
ORDER BY tps_indispo DESC
LIMIT 10
```

List of alerts with downtime(s) occured but which have been acknowledged  :
```erb
SELECT * FROM `Alert` WHERE downtime_occurence > 0 and acknowledgement_id is NOT NULL
```
