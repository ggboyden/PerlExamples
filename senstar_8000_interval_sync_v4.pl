#!/usr/bin/perl -w
# ****************************************************************
#   Written by Glenn Boyden
#   first created updated on 12/7/2008
#   Last updated on 2/12/2008
#   Description:  This perl script will read the interval table on
#   165.218.171.179 in database tracedata.  It will sync latest 
#   real data in the interval table into a duplicate table located 
#   in the noc_core database on the NOC's MySQL server. It will 
#   need to ignore the zero filled future records used by SEC 
#   development to assist their graphing application.
#   This synced data will provide the base table for NOC portal to 
#   display the graphs of the 8000 call data. Each new record is 
#   updated each 15 minutes. The data will also be analyzed to 
#   compare the total calls with the answered calls. If there is 
#   more than a x% difference, a SNMP trap will be generated. The 
#   recent total number of registered phones will also be 
#   compared to each new reading. A drop or spike of x% or more will
#   also generate a SNMP trap.
# ****************************************************************

use DBI;
use strict;
use Time::Local; 
use Date::Format;
use MIME::Entity;
  
my $month;
my $day;
my $year;
my $unixtime;
my @f = localtime(time);
$month = strftime("%L",@f);
$day = strftime("%e",@f);
$year = strftime("%Y",@f);

my $tracedb_ip_address = '172.19.244.157';
my $noc_mysql_db_ip_address = '172.16.20.83';
# old my $databasename = 'tracedata';
my $databasename = 'acs'; 
#my $admin_email_list = 'glenn.boyden@siemens.com, 4694268902@cingularme.com, netopscenter.us@siemens.com, ryan.dehart@siemens.com, barry.talley@siemens.com, michael.saiz@siemens.com, robert.cheney@siemens.com, david.hendrix@siemens.com';
my $admin_email_list = 'netopscenter.us@siemens-enterprise.com, glenn.boyden@siemens-enterprise.com';

my $from_email_user = 'netopscenter.us@siemens-enterprise.com';
my $subject_line = '';
my $preface = '';
my $body = '';

my $dbh1;
my $dbh2;
my $q1;
my $q2;
my $sth1;
my $sth2;
my @row = '0';
my $last_index_id = '0';

my $indx;
my $cap_time;
my $customer_id = 67;
my $sen_date;
my $ip;
my $total;
my $answered;
my $abandoned;
my $incomplete;
my $erroredcalls;
my $registers;
my $subscribes;
my $notifies;
my $packetssent;
my $packetsrecv;
my $lost;
my $jitter;
my $delay;
my $duplicate;
my $node = "senstar_irv_irvc069v";
my $node1 = "senstar_irv_irvc069v";
my $node2 = "senstar_irv_irvc069v";
my $destination = '207.158.104.162'; #if script is run on aggregator, use 127.0.0.1 
my $destination2 = '207.158.104.163'; #if script is run on aggregator, use 127.0.0.1
my $call_total = 0;
my $call_answered = 0;
my $registeredlines = 0;
my $call_threshold = 0;
my $register_threshold = 0;
my $reg_upper_limit = 0;
my $reg_lower_limit = 0;
my $call_alarm = 0;
my $reg_alarm = 0;
my $workday = 0;
my $workhour = 0;
my $nonholiday = 0;
my $alarm_on_call_data = 0;
my $call_percentage = 0;
my $last_update_hours = 0;
 
print "$month-$day-$year\n"; 

$unixtime = timelocal(0,0,0,$day,$month-1,$year) * 1000;
#print $unixtime."\n";

# NOC's mysql database
print "Connecting to Siemens NOC's database\n";
#$dbh1 = DBI->connect("dbi:mysql:noc_core:172.16.20.83","nocautomation","secret1") or die "Unable to connect to NOC database";
$dbh1 = DBI->connect("dbi:mysql:noc_core:172.16.20.83","SIRA-Trace",'!Trace@service1') or die "Unable to connect to NOC database";
# tracedata db
print "Connecting to hipath 8000 trace database\n";
$dbh2= DBI->connect("dbi:mysql:$databasename:$tracedb_ip_address",'nocautomation','secret1') or die "Unable 
to connect to trace database";

print "checking schedule for alarming on call data\n";
  $q1 = "select
        if((dayofweek(now()) > 1) and (dayofweek(now()) < 6), 1,0) as workday,
        if((hour(now()) > 7) and (hour(now()) < 17), 1,0) as workhour,
        if((select date(holiday_date) from holiday_schedule where date(now()) = date(holiday_date)),0,1) as nonholiday "; 
                 
  $sth1 = $dbh1->prepare($q1);
  $sth1->execute or die "Unable to execute query";

	while(@row = $sth1->fetchrow_array) {
			$workday = $row[0];
			$workhour = $row[1];
			$nonholiday = $row[2];
			print "1 = true 0 = false : workday = $workday  workhour = $workhour   nonholiday = $nonholiday\n";
	}
 
 if (($workday+$workhour+$nonholiday) == 3) {
      $alarm_on_call_data = 1;
      print "alarming on total vs answered calls has been enabled for this cycle\n";
 
 };  

print "update all previous records with new values\n";
# update all previous records with new values
# Get the latest events from belview
#get the last ID number captured.
#  $q1 = "select max(sen_index) from hipath8k_interval"; 
  $q1 = "select sen_index from hipath8k_interval where customer_id = $customer_id order by sen_index limit 1"; 
                 
  $sth1 = $dbh1->prepare($q1);
  $sth1->execute or die "Unable to execute query";

	while(@row = $sth1->fetchrow_array) {
			$last_index_id = $row[0];
			print "[last index id = $last_index_id]\n";
	}

# DEV reset the index on the fade tool. to keep things going, we need to adjust the index to continue. 
  $last_index_id = $last_index_id  - 17665;

  if ($last_index_id < 1 ){ $last_index_id = 0 };

  $q2 = "SELECT 
        `Index`,
        `Date`, 
        `IP`, 
        `Total`, 
        `Answered`, 
        `Abandoned`, 
        `Incomplete`, 
        `ErroredCalls`, 
        `RegisteredLines`, 
        `Registers`, 
        `StableCalls`, 
        `Notify`, 
        `PacketsSent`, 
        `PacketsRecv`, 
        `Lost`, 
        `Jitter`, 
        `Delay`, 
        `Duplicate`,
        `Valid` 
        FROM `interval` 
        WHERE `Valid` > 1 and `Index` <= $last_index_id ORDER BY `Index`";
  #WHERE `Index` > $last_index_id and `Date` < (now() - interval 12 minute) ORDER BY `Index`

  #print "$q2\n\n";
  $sth2 = $dbh2->prepare($q2);
  $sth2->execute or die "Unable to execute query";

#    if ($last_index_id  => $row[0]){ exit };


  $q1 = '';

  while(@row = $sth2->fetchrow_array) {
	
          $q1 = "UPDATE hipath8k_interval 
                  set customer_id = $customer_id,
                  total = $row[3],    
                  answered = $row[4],    
                  abandoned = $row[5],    
                  incomplete = $row[6],    
                  erroredcalls = $row[7], 
                  registeredlines = $row[8],
                  registers = $row[9],
                  subscribes = $row[10],
                  notifies = $row[11],
                  packetssent = $row[12],
                  packetsrecv = $row[13],
                  lost = $row[14],
                  jitter = $row[15],
                  delay = $row[16],
                  duplicate = $row[17],
                  valid = $row[18]
                  where sen_index = $row[0]"; 
          #print "$q1\n";       
          $sth1 = $dbh1->prepare($q1);
          $sth1->execute or die "Unable to execute query";
}

@row = '0';
# if the trace data has stopped updataing in the FADE server, send notification
#  $q1 = "SELECT hour(timediff(now(),max(sen_date))) FROM hipath8k_interval where customer_id = $customer_id";
#  $sth1 = $dbh1->prepare($q1);
#  $sth1->execute or die "Unable to execute query";

#	while(@row = $sth1->fetchrow_array) {
#			$last_update_hours = $row[0];
#	}
 # if ($last_update_hours > 0 ){ 
#       $subject_line = "SEN FADE server has stalled: $last_update_hours hour(s)\n";
#       print $subject_line;
       #call_admin();
#  };

#get the last ID number captured.
  $q1 = "select sen_index from hipath8k_interval where customer_id = $customer_id order by sen_index limit 1"; 
                 
  $sth1 = $dbh1->prepare($q1);
  $sth1->execute or die "Unable to execute query";

	while(@row = $sth1->fetchrow_array) {
			$last_index_id = $row[0];
			print "[last index id = $last_index_id]\n";
	}
  if ($last_index_id < 1 ){ $last_index_id = 0 };

# DEV reset the index on the fade tool. to keep things going, we need to adjust the index to continue. 
  $last_index_id = $last_index_id - 17665;

  if ($last_index_id < 1 ){ $last_index_id = 0 };
	
# Get the latest events from tracedata
 print "getting the latest events from tracedata\n";
 
  $q2 = "SELECT 
        `Index`,
        `Date`, 
        `IP`, 
        `Total`, 
        `Answered`, 
        `Abandoned`, 
        `Incomplete`, 
        `ErroredCalls`, 
        `RegisteredLines`, 
        `Registers`, 
        `StableCalls`, 
        `Notify`, 
        `PacketsSent`, 
        `PacketsRecv`, 
        `Lost`, 
        `Jitter`, 
        `Delay`, 
        `Duplicate`,
        `Valid` 
        FROM `interval` 
        WHERE `Valid` > 1 and `Index` > $last_index_id ORDER BY `Index`";
  #WHERE `Index` > $last_index_id and `Date` < (now() - interval 12 minute) ORDER BY `Index`

  #print "$q2\n\n";
  $sth2 = $dbh2->prepare($q2);
  $sth2->execute or die "Unable to execute query";

#    if ($last_index_id  => $row[0]){ exit };


  $q1 = '';
  my $insert_cnt = 0;
 
  while(@row = $sth2->fetchrow_array) {
          $q1 = "INSERT hipath8k_interval 
                  set cap_time = now(),
                  customer_id = $customer_id,
                  sen_index = $row[0],
                  sen_date = \'$row[1]\', 
                  ip = \'$row[2]\',    
                  total = $row[3],    
                  answered = $row[4],    
                  abandoned = $row[5],    
                  incomplete = $row[6],    
                  erroredcalls = $row[7], 
                  registeredlines = $row[8],
                  registers = $row[9],
                  subscribes = $row[10],
                  notifies = $row[11],
                  packetssent = $row[12],
                  packetsrecv = $row[13],
                  lost = $row[14],
                  jitter = $row[15],
                  delay = $row[16],
                  duplicate = $row[17],
                  valid = $row[18],
                  initial_total = $row[3],
                  initial_answered = $row[4],
                  initial_registeredlines = $row[8]"; 

          print "total = $row[3]  answered = $row[4]\n";       
          $sth1 = $dbh1->prepare($q1);
          $sth1->execute or die "Unable to execute query";
          $insert_cnt = $insert_cnt + 1;

}          


#get the NEXT TO LAST last ID number captured. (to provide time for the trace database to add better values to the database)
  $q1 = "select total, answered, registeredlines from hipath8k_interval where customer_id = $customer_id and sen_index = (select max(sen_index)-1 from hipath8k_interval where customer_id = $customer_id)"; 
                 
  $sth1 = $dbh1->prepare($q1);
  $sth1->execute or die "Unable to execute query";

  $call_total = 0;
  $call_answered = 0;
  $registeredlines = 0;

	while(@row = $sth1->fetchrow_array) {
          $call_total = $row[0];
          $call_answered = $row[1];
          $registeredlines = $row[2];
	}

if ($insert_cnt > 0){

  $q1 = "SELECT threshold as call_threshold FROM hipath8k_threshold where customer_id = $customer_id and chart_id = 0"; 
  $sth1 = $dbh1->prepare($q1);
  $sth1->execute or die "Unable to execute query";

	while(@row = $sth1->fetchrow_array) {
			$call_threshold = $row[0];
	}

  if ($call_total ne 0) {
        if ($call_answered ne 0){
              $call_percentage = (($call_answered / $call_total) * 100);
              if ($call_percentage < $call_threshold ) {
                    $call_alarm = 1;
              };
        };
  };

  if ($call_total == 0){
     $call_alarm = 1;
  };

  if ($call_answered == 0){
     $call_alarm = 1;
  };
  
  
  $q1 = "SELECT threshold as register_threshold FROM hipath8k_threshold where customer_id = $customer_id and chart_id = 2"; 
  $sth1 = $dbh1->prepare($q1);
  $sth1->execute or die "Unable to execute query";

	while(@row = $sth1->fetchrow_array) {
			$register_threshold = $row[0];
	}
   
  $q1 = "SELECT COUNT(registeredlines) AS qty, 
          ROUND(registeredlines + (registeredlines * (threshold / 100)),0) AS upper_limit,
          ROUND(registeredlines - (registeredlines * (threshold / 100)),0) AS lower_limit
          FROM hipath8k_interval
          LEFT JOIN hipath8k_threshold ON hipath8k_threshold.customer_id = hipath8k_interval.customer_id AND chart_id = 2
          WHERE registeredlines > 0
          AND hipath8k_interval.customer_id = $customer_id
          AND DATE_SUB(CURDATE(),INTERVAL 30 DAY) <= sen_date
          GROUP BY registeredlines 
          ORDER BY qty DESC
          LIMIT 1";
    
  $sth1 = $dbh1->prepare($q1);
  $sth1->execute or die "Unable to execute query";

  while(@row = $sth1->fetchrow_array) {
	   $reg_upper_limit = $row[1];
     $reg_lower_limit = $row[2];
		 #print "[register threshold = $call_threshold]\n";
	}

  if ($registeredlines > $reg_upper_limit){
    $reg_alarm = 1;
  };

  if ($registeredlines == 0){
    $reg_alarm = 0;
  };

  if ($registeredlines < $reg_lower_limit){
    $reg_alarm = 1;
  };
    
  $preface = $preface."[call threshold = $call_threshold]\n";
  $preface = $preface."[call total = $call_total]\n";
  $preface = $preface."[call answered = $call_answered]\n";
  $preface = $preface."[percent answered = $call_percentage]\n\n";
  $preface = $preface."[register upper limit = $reg_upper_limit]\n";
  $preface = $preface."[registered lines = $registeredlines]\n";
  $preface = $preface."[register lower limit = $reg_lower_limit]\n";
  print $preface;

  
  if ($alarm_on_call_data > 0) {
            if ($call_alarm > 0) { 
                system qq(snmptrap -v 1 -c public $destination 1.3.6.1.2.1.27.6 \'\' 6 1 \'\' 1.3.6.1.4.1.999999 s \"$node\" 1.3.6.1.4.1.999999 s \"Call performance past threshold\" 1.3.6.1.4.1.999999 s \"Alarm\" );
                system qq(snmptrap -v 1 -c public $destination2 1.3.6.1.2.1.27.6 \'\' 6 1 \'\' 1.3.6.1.4.1.999999 s \"$node\" 1.3.6.1.4.1.999999 s \"Call performance past threshold\" 1.3.6.1.4.1.999999 s \"Alarm\" );
                print "sending ALARM for SEN STAR 8K Call performance past threshold\n";
                $subject_line = "ALARM sent for SEN STAR 8K Call performance outside of threshold";
                call_admin();
            };
            
  };
  
  if ($call_alarm == 0) { 
      system qq(snmptrap -v 1 -c public $destination 1.3.6.1.2.1.27.6 \'\' 6 1 \'\' 1.3.6.1.4.1.999999 s \"$node\" 1.3.6.1.4.1.999999 s \"Call performance past threshold\" 1.3.6.1.4.1.999999 s \"Clear\" );
      system qq(snmptrap -v 1 -c public $destination2 1.3.6.1.2.1.27.6 \'\' 6 1 \'\' 1.3.6.1.4.1.999999 s \"$node\" 1.3.6.1.4.1.999999 s \"Call performance past threshold\" 1.3.6.1.4.1.999999 s \"Clear\" );
      print "sending CLEAR for SEN STAR 8K Call performance past threshold\n";
      #print "\n";
  };                 

  if ($reg_alarm > 0) { 
      system qq(snmptrap -v 1 -c public $destination 1.3.6.1.2.1.27.6 \'\' 6 1 \'\' 1.3.6.1.4.1.999999 s \"$node\" 1.3.6.1.4.1.999999 s \"Registered lines past threshold\" 1.3.6.1.4.1.999999 s \"Alarm\" );
      system qq(snmptrap -v 1 -c public $destination2 1.3.6.1.2.1.27.6 \'\' 6 1 \'\' 1.3.6.1.4.1.999999 s \"$node\" 1.3.6.1.4.1.999999 s \"Registered lines past threshold\" 1.3.6.1.4.1.999999 s \"Alarm\" );
      print "sending ALARM for SEN STAR 8K Registered lines past threshold\n";
      $subject_line = "ALARM sent for SEN STAR 8K Registered lines outside of upper/lower limits of threshold";
      call_admin();
  };
  
  if ($reg_alarm == 0) { 
      system qq(snmptrap -v 1 -c public $destination 1.3.6.1.2.1.27.6 \'\' 6 1 \'\' 1.3.6.1.4.1.999999 s \"$node\" 1.3.6.1.4.1.999999 s \"Registered lines past threshold\" 1.3.6.1.4.1.999999 s \"Clear\" );
      system qq(snmptrap -v 1 -c public $destination2 1.3.6.1.2.1.27.6 \'\' 6 1 \'\' 1.3.6.1.4.1.999999 s \"$node\" 1.3.6.1.4.1.999999 s \"Registered lines past threshold\" 1.3.6.1.4.1.999999 s \"Clear\" );
      print "sending CLEAR for SEN STAR 8K Registered lines past threshold\n";
  };
}

  $sth1->finish;

  $sth2->finish;
  print "Disconnecting from HiPath 8000 Trace database\n";
  $dbh2->disconnect;
  print "Disconnecting from NOC's database\n";
  $dbh1->disconnect;
  exit;



sub call_admin {
  my $sendToAddress = $admin_email_list;
	my $myEmailAddress = $from_email_user;
	my $mail;
	$mail = MIME::Entity->build(
      Type =>"multipart/mixed", 
			From =>$myEmailAddress,
			To =>$sendToAddress,
      Subject => $subject_line);
   
	### Add Attachement 1 (the body)
	$body = "The Siemens NOC HiPath 8000 Performance Monitor has detected an issue.\n\n";
  $body = $body."Goto to www.siemensnoc.net, login, and navigate to Tools/HiPath 8000 Monitor to see actual history of this event.\n";
  $body = $body."Three charts are provided in the pull-down list.  Calls, Performance, and Registrations.\n";
  $body = $body."The period can range from the last 24 hours to the last 30 days.\n";   
  $body = $body."Below are the last values and threshold settings read.\n";
  $body = $body.$preface;

	$mail->attach(
   			Type     => 'TEXT',
		    Data     => $body
	);

	### Send the message with attachment
	open MAIL,"|/usr/lib/sendmail -t -oi -oem" or die"open: $!";
	$mail ->print(\*MAIL);
	close MAIL;
}

sub tracedata_timeout_notification {
  my $sendToAddress = $admin_email_list;
	my $myEmailAddress = $from_email_user;
	my $mail;
	$mail = MIME::Entity->build(
      Type =>"multipart/mixed", 
			From =>$myEmailAddress,
			To =>$sendToAddress,
      Subject => $subject_line);
   
	### Add Attachement 1 (the body)
	$body = "The Siemens NOC HiPath 8000 Performance Monitor has detected an issue.\n\n";
  $body = $body."Goto to www.siemensnoc.net, login, and navigate to Tools/HiPath 8000 Monitor to see actual history of this event.\n";
  $body = $body."Three charts are provided in the pull-down list.  Calls, Performance, and Registrations.\n";
  $body = $body."The period can range from the last 24 hours to the last 30 days.\n";   
  $body = $body."Below are the last values and threshold settings read.\n";
  $body = $body.$preface;

	$mail->attach(
   			Type     => 'TEXT',
		    Data     => $body
	);

	### Send the message with attachment
	open MAIL,"|/usr/lib/sendmail -t -oi -oem" or die"open: $!";
	$mail ->print(\*MAIL);
	close MAIL;
}
