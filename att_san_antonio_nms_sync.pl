#!/usr/bin/perl -w
# ****************************************************************
#   Written by Glenn Boyden
#   Last updated on 5/23/2008
#   Description:  This perl script will perfrom a daily capture
#   of the belviewnmsdb Event table with a timestamp of the capture. 
#   The data will be stored in the NOC's aggregator server so that 
#   reports can be generated spanning more than 7 days (monthly)
# ****************************************************************

use DBI;
use strict;
use Time::Local; 
use Date::Format;
my $month;
my $day;
my $year;
my $unixtime;
my @f = localtime(time);
$month = strftime("%L",@f);
$day = strftime("%e",@f);
$year = strftime("%Y",@f);

my $location = 'San Antonio';
my $nms_ip_address = '10.2.91.253';
my $aggregator_ip_address = '10.2.47.246';
print "$month-$day-$year\n"; 

$unixtime = timelocal(0,0,0,$day,$month-1,$year) * 1000;
print $unixtime."\n";


# NOC's mysql database
print "Connecting to Siemens NOC's database\n";
my $dbh1 = DBI->connect("dbi:mysql:performance:$aggregator_ip_address",'nocautomation','') or die "Unable 
to connect to NOC database";


# belviewnmsdb
print "Connecting to $location belviewnmsdb database\n";
my $dbh2= DBI->connect("dbi:mysql:belviewnmsdb:$nms_ip_address",'snoc','') or die "Unable 
to connect to NOC database";




my $q2 = "SELECT 
          TEXT, 
          CATEGORY,
          DDOMAIN, 
          NETWORK, 
          NODE,
          ENTITY,
          SEVERITY, 
          (TTIME * .001) as TTIME, 
          from_unixtime(TTIME * .001) as event_time,
          SOURCE, 
          HELPURL, 
          WEBNMS,
          GROUPNAME, 
          OWNERNAME
          FROM Event 
          WHERE SEVERITY < 6 order by TTIME";

my $sth2 = $dbh2->prepare($q2);
$sth2->execute or die "Unable to execute query";

my @row;
my $q1 = '';

while(@row = $sth2->fetchrow_array) {
	
          $q1 = "INSERT event_log 
                  set cap_time = now(),
                  location = \'$location\',
                  TEXT = \'$row[0]\',  
                  CATEGORY = \'$row[1]\',
                  DDOMAIN= \'$row[2]\', 
                  NETWORK= \'$row[3]\', 
                  NODE= \'$row[4]\',
                  ENTITY= \'$row[5]\',
                  SEVERITY= \'$row[6]\', 
                  TTIME= \'$row[7]\',
                  event_time=\'$row[8]\', 
                  SOURCE= \'$row[9]\', 
                  HELPURL= \'$row[10]\', 
                  WEBNMS= \'$row[11]\',
                  GROUPNAME= \'$row[12]\', 
                  OWNERNAME= \'$row[13]\'"; 
                  
          my $sth1 = $dbh1->prepare($q1);
          
          $sth1->execute or die "Unable to execute query";
          
          print localtime(int($row[7]))."-".$row[0]."-".$row[3]."\n";

}

$sth2->finish;
print "Disconnecting from NMS database\n";
$dbh2->disconnect;
print "Disconnecting from NOC's database\n";
$dbh1->disconnect;
exit;
