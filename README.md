# centreon_consolidate_alerts

In French : <br>
Ce script répond à un besoin de faire du reporting sur les alertes Centreon. <br> <br>
Ce script va lire les données des 3 tables centreon_storage.logs + downtimes + acknownledgements
dans le créneau horaire [--start => --end]. Le script va alimenter la table [your_database].Alert
où chaque entrée de la table représente une alerte Centreon. Le fichier de conf permet de renseigner
les informations de connexion pour la database centreon_storage et votre database pour la table Alert. <br>
<b>NOTE:</b> l'option --conf est obligatoire

## Requirements

  - Centreon database
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

Launch the script :
```erb
# ./centreon_consolidate_alerts.pl --start 01/10 --end 01/11  --verbose --conf database_info.conf > centreon_consolidate_alerts.log
```

## Examples 

TOP10 unavailability with downtime supported (<b>if your ping service is called 'ping'</b>) :
```erb
SELECT host_name, service_description, service_id, SUM( interpreted_duration ) AS tps_indispo
FROM Alert
WHERE service_description LIKE 'ping'
GROUP BY service_id
ORDER BY tps_indispo DESC
LIMIT 10


```

