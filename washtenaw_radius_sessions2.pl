#!/usr/bin/perl -w
# ****************************************************************
#   Written by Glenn Boyden
#   Last updated on 2/4/2007
#   Description:  This perl script will read the tivkrt records and
#   determine the last record for each session.  It will then take 
#   last records and consolidate them into a separate table.
# ****************************************************************

use DBI;
use strict;
use Time::Local; 
use Date::Format;
use Time::Interval;

my $month;
my $day;
my $year;
my $unixtime;
my @f = localtime(time);
$month = strftime("%L",@f);
$day = strftime("%e",@f);
$year = strftime("%Y",@f);
$unixtime = timelocal(0,0,0,$day,$month-1,$year) * 1000;

# NOC's mysql database connection 1
print "Connecting to Siemens NOC's database\n";
my $dbh1 = DBI->connect("dbi:mysql:washtenaw:127.0.0.1",undef, undef) or die "Unable 
to connect to NOC database";

# NOC's mysql database connection 3
print "Connecting to Siemens NOC's database\n";
my $dbh2 = DBI->connect("dbi:mysql:washtenaw:127.0.0.1",undef,undef) or die "Unable 
to connect to NOC database";

my $readline;
my $reccnt = 0;

my $user_name_1;
my $user_class_1;
my $wip_timestamp_1;
my $bytes_up_1;
my $bytes_down_1;
my $duration_1;
my $status_1;
my $nas_port_id_1;
my $bytes_down_subtract = 0; 				
my $bytes_up_subtract = 0; 

my $user_name_2;
my $user_class_2;
my $wip_timestamp_2;
my $bytes_up_2;
my $bytes_down_2;
my $duration_2;
my $status_2;
my $nas_port_id_2;
my $time_from_month_start = 0;

my $session_cnt = 0;
my $session_start = 0;
my $session_time_hi = 0;

my $q1 = '';
my $sth1;
my $q2 = '';
my $sth2;

my @row;
my @users;
my $cnt = 0;
my $user;

# Get a list of all the users
$q1 = "SELECT user_name from radius_tickets group by user_name order by user_name";
#print "$q1\n";
$sth1 = $dbh1->prepare($q1);
$sth1->execute or die "Unable to execute query";			

# populate the array with the user names. 
while(@row = $sth1->fetchrow_array) {
	$cnt = $cnt + 1;
	$users[$cnt] = $row[0];
	print "user: $users[$cnt]\n";
}

undef @row;
my $user_cnt = 0;
my $ticket_cnt = 0;


foreach $user (@users){
	$user_cnt = $user_cnt + 1;

	# get count of number of tickets
	$q1 = "select count(*) from radius_tickets where user_name = \'$users[$user_cnt]\' and nas_port = \'\' order by wip_timestamp";
	$sth1 = $dbh1->prepare($q1);
	$sth1->execute or die "Unable to execute query";	

	while(@row = $sth1->fetchrow_array) {
		$ticket_cnt = $row[0];
		print "$users[$user_cnt] has $ticket_cnt tickets and ";
	}


	$q1 = "select * from radius_tickets where user_name = \'$users[$user_cnt]\' and nas_port = \'\' order by wip_timestamp";
	#print "$q1\n";
	$sth1 = $dbh1->prepare($q1);
	$sth1->execute or die "Unable to execute query";			

	$cnt = 0;
	$bytes_down_subtract = 0; 				
	$bytes_up_subtract = 0; 				


	# populate the array with the user names. 
	while(@row = $sth1->fetchrow_array) {
		$cnt = $cnt + 1;
		$user_name_1 = $row[1]; 
		$user_class_1 = $row[2];
		$bytes_down_1 = $row[3];
		$bytes_up_1 = $row[4];
		$duration_1 = $row[5];
		$wip_timestamp_1 = $row[6];
		$status_1 = $row[8];
		$nas_port_id_1 = $row[10];
		$time_from_month_start = $row[11];

		# On first record, check to the status value - see if it is a continuation from prevoious month - subtract bytes
	 	if ($cnt == 1) {
			if ($status_1 eq 'Alive'){
				if ($time_from_month_start = $duration_1) { 
					$bytes_down_subtract = $bytes_down_1;
					$bytes_up_subtract = $bytes_up_1;
				}			
			}
			
		}


		# Check for stop records - move them to radius_sessions
		if ($status_1 eq 'Stop') {
			if ($cnt > 1) {
				#insert record into radius_session table
	
				$q2 = "INSERT radius_session 
					set user_name = \'$user_name_1\',
					user_class  = \'$user_class_1\', 
					wip_timestamp = \'$wip_timestamp_1\', 				
					bytes_down = $bytes_down_1 - $bytes_down_subtract, 				
					bytes_up = $bytes_up_1 - $bytes_up_subtract, 				
					duration = $duration_1,
					session_status = \'$status_1\', 
					nas_port = \'$nas_port_id_1\' ";

				#print "sql: $q2\n";

				$sth2 = $dbh2->prepare($q2);
				$sth2->execute or die "Unable to execute query";
				$session_cnt = $session_cnt + 1;
				$session_start = $wip_timestamp_1; # capture the new start time.	
				$bytes_down_subtract = 0; 				
				$bytes_up_subtract = 0; 				

			}
		}
		
		# check last record. if Alive, make this a stop record and move to radius_sessions
		if ($cnt == $ticket_cnt) {
			if ($status_1 eq 'Alive') {
				print " $status_1 ";
				#insert record into radius_sessions table
				$status_1 = 'F_Stop';
				$q2 = "INSERT radius_session 
					set user_name = \'$user_name_1\',
					user_class  = \'$user_class_1\', 
					wip_timestamp = \'$wip_timestamp_1\', 				
					bytes_down = $bytes_down_1 - $bytes_down_subtract, 				
					bytes_up = $bytes_up_1 - $bytes_up_subtract, 				
					duration = $duration_1,
					session_status = \'$status_1\', 
					nas_port = \'$nas_port_id_1\' ";

				#print "sql: $q2\n";
				$sth2 = $dbh2->prepare($q2);
				$sth2->execute or die "Unable to execute query";
				$session_cnt = $session_cnt + 1;
				$session_start = $wip_timestamp_1; # capture the new start time.	
			}
		}
	}

	if ($session_cnt == 0){
		print "cnt = $cnt";
	}
	print " $session_cnt sessions\n";
	$session_cnt = 0; # Next user
	
}
print "Record count = $cnt\n";

print "Disconnecting from NOC database\n";
$dbh1->disconnect;

exit;
