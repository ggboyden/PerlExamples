#!/usr/bin/perl -w
# ****************************************************************
#   Written by Glenn Boyden
#   Last updated on 7/15/2008
#   Description:  This perl script will generate the final customer 
#   monthly ticket report 
# ****************************************************************

	use strict;
	use DBI;
	use Time::Local; 
    	use Date::Format;
    	use Time::Interval;
    	use Spreadsheet::WriteExcel;
    	use Net::SCP::Expect;
	use MIME::Entity;

    	my @row = "";
    	my @unl; # unl = unreachable node list
    	my @downtime; 
    	my @eventtext;
    	my $cnt = 0;
    	my @lines = "";
    	my $host = "";
    	my $response = "";
    	my $position = "";
    	my $telneterror = "";
    	my $t = "";
    	my @host_array;
    	my $responselines = "";
    	my $ignore = 0;
    	my $ticket;
    	my $rptmonth;
    	my $rptyear;
    	my $filename;
    	my $recordcnt;
    	my $rowstart;

    	my @remedy_ticket_number;
    	my @alarm_date;
    	my @status;
    	my @closed_date;
    	my @city;
    	my @address;
    	my @latitude;
    	my @longitude;
    	my @device_name;
    	my @device_ip;
    	my @problem_description;
	    my @error_description;
	    my @incident_type;
    	my @summary;
	    my $sync_status;
	    my $sync;
	    my $csvline;
	    my $body;
	    
	    my @maintenance;
	    my @outage;
	    my @test;  
      my @non_outage;
	    my @duplicate;
	    
	    my $workbook = '';
      my $worksheet = '';
      my $worksheet2 = '';
      my $worksheet3 = '';
      my $worksheet4 = '';
      my $worksheet5 = '';
      my $worksheet6 = '';
      my $worksheet7 = '';
      
      my $title = '';
      my $title2 = '';
      my $header = '';
      my $wrap = '';
      my $wrap2 = '';
      my @event_frequency = '';
      my $rpt_month = 1;
      my $q1 = "";
      my $sth1;	

	    $row[0] = "";
      $row[1] = "";
      $row[2] = "";
      $row[3] = "";
      $row[4] = "";
      $row[5] = "";
      $row[6] = "";
      $row[7] = "";
      $row[8] = "";
      $row[9] = "";
      $row[10] = "";
      $row[11] = "";
      $row[12] = "";
      $row[13] = "";
      $row[14] = "";

    	# NOC's mysql database connection 1
    	print "Connecting to Siemens NOC's database\n";
    	my $dbh1 = DBI->connect("dbi:mysql:noc_core:172.16.20.83","nocautomation","") or die "Unable 
    	to connect to NOC database";


	# Get sync_status syncing means wait and check again
	$sync = 1;

	while ($sync > 0) {
		# Get database date for yesterday
        	my $q1 = "SELECT sync_status from sync_status";

		# execute the query
		my $sth1 = $dbh1->prepare($q1);
		$sth1->execute or die "Unable to execute query";

		while(@row = $sth1->fetchrow_array) {
			$sync_status = $row[0];
			print "[$sync_status]\n";
		}

		
	    	if ($sync_status eq "current") {
			print "sync is current\n";
			$sync = 0;
		} else {sleep(5);}
		
	} 
     
while ($rpt_month < 7)	{

		#$rptmonth =   $rpt_month;	

		$rptyear = 2009;

		$filename = '2009_'.$rpt_month.'_00';

	# Get name of month
  my $q1 = "SELECT date_format(\"$rptyear-$rpt_month-01\", '%M')";
print "$q1\n";
	# execute the query
	my $sth1 = $dbh1->prepare($q1);
	$sth1->execute or die "Unable to execute query";

	while(@row = $sth1->fetchrow_array) {
		$rptmonth = $row[0];
	}

	
## Create Excel Workbook for all the work sheets to be placed in
$workbook  = Spreadsheet::WriteExcel->new("/home/ggboyden/Documents/perl/monthly_ntr_$filename.xls");


###############################################
##  St Louis event frequency                 ##
###############################################
	$cnt = 0;
  @remedy_ticket_number = '';
  @alarm_date = '';
  @status = '';
  @closed_date = '';
  @city = '';
  @address = '';
  @latitude = '';
  @longitude = '';
  @device_name = '';
  @device_ip = '';
  @problem_description = '';
	@error_description = '';
  @summary = '';
  @maintenance = '';
	@outage = '';
	@test = '';
	@non_outage ='';
	@duplicate = '';
	
	$q1 = "SELECT a.customer_id, a.noc_device_name as device_name, b.ip_address, count(*) as event_frequency, b.city, b.address_1, b.latitude, b.longitude FROM tickets a left join devices b on a.noc_device_name = b.noc_device_name where a.customer_name_1 like \'ATT%\' and month(a.create_date) = $rpt_month and year(create_date) = \'2008\' and a.noc_device_name like \'att_st%\' group by b.ip_address order by event_frequency desc";
  $q1 = "SELECT
            a.customer_id,
            a.noc_device_name as device_name,
            b.ip_address, count(*) as event_frequency,
            sum(if(a.summary like \'%Outage: no%\',1,0)) as non_outage,
            sum(if(a.summary like \'%Outage: yes%\',1,0)) as outage,
            sum(if(a.summary like \'%NCR%\',1,0)) as maintenance,
            sum(if(a.summary like \'%Duplicate Alarm: Yes%\',1,0)) as 'duplicate',
            sum(if(a.summary like \'%test%\',1,0)) as test,
            b.city,
            b.address_1,
            b.latitude,
            b.longitude
            FROM tickets a left join devices b on a.noc_device_name = b.noc_device_name
            where a.customer_name_1 like \'ATT%\' and
            month(a.create_date) = $rpt_month and
            year(create_date) = '2009' and
            a.noc_device_name like \'att_st%\'
            group by b.ip_address order by event_frequency desc";

	#print "\n".$q1."\n";

	# execute the query
	$sth1 = $dbh1->prepare($q1);
	$sth1->execute or die "Unable to execute query";
  
  # populate the array with the node IP values
	while(@row = $sth1->fetchrow_array) {
		$device_name[$cnt] = $row[1];
		$device_ip[$cnt] = $row[2];
		$event_frequency[$cnt] = $row[3];
    $non_outage[$cnt] = $row[4];
    $outage[$cnt] = $row[5];
    $maintenance[$cnt] = $row[6];
    $duplicate[$cnt] = $row[7];
    $test[$cnt] = $row[8];
    if ($row[9] eq "") {$row[9] = "TBD - check device name"};
		$city[$cnt] = $row[9];
		if ($row[10] eq "") {$row[10] = "TBD - check device name"};
		$address[$cnt] = $row[10];
		if ($row[11] eq "") {$row[11] = "TBD - check device name"};
		$latitude[$cnt] = $row[11];
		if ($row[12] eq "") {$row[12] = "TBD - check device name"};
		$longitude[$cnt] = $row[12];

		$cnt = $cnt + 1;
	}
  $recordcnt = $cnt-1;
  
	# Create a new workbook and add a worksheet
    	$worksheet3 = $workbook->add_worksheet("St Louis Event Freq");

    	# Set the column width for columns
    	$worksheet3->set_column(0, 0, 40); #
    	$worksheet3->set_column(1, 1, 17); # 
    	$worksheet3->set_column(2, 2, 21); # 
    	$worksheet3->set_column(3, 3, 17); # 
    	$worksheet3->set_column(4, 4, 10); #
    	$worksheet3->set_column(5, 5, 15); #
    	$worksheet3->set_column(6, 6, 11); #
    	$worksheet3->set_column(7, 7, 8); #
    	$worksheet3->set_column(8, 8, 20); #
    	$worksheet3->set_column(9, 9, 20); #
    	$worksheet3->set_column(10, 10, 20); #
    	$worksheet3->set_column(11, 11, 20); #
    	$worksheet3->set_column(12, 12, 20); #
    	
    	# Create a format for the column headings
    	$title = $workbook->add_format();
    	$title->set_bold();
    	$title->set_size(16);
    	$title->set_bg_color('aqua');
    	$title->set_color('black');

    	# Create a format for the column headings
    	$title2 = $workbook->add_format();
    	$title2->set_bold();
    	$title2->set_size(8);
    	$title2->set_bg_color('aqua');
    	$title2->set_color('black');

    	# Create a format for the column headings
    	$header = $workbook->add_format();
    	$header->set_bold();
    	$header->set_size(12);
    	$header->set_bg_color('black');
    	$header->set_color('white');

    	$wrap = $workbook->add_format();
    	$wrap->set_text_wrap();

     	$wrap2 = $workbook->add_format();
    	$wrap2->set_bold();
    	$wrap2->set_size(8);
    	$wrap2->set_bg_color('aqua');
    	$wrap2->set_color('black');
    	$wrap2->set_text_wrap();

	# Scale the inserted image: width x 0.4, height x 0.4
	$worksheet3->insert_image('D1', '/home/ggboyden/Documents/perl/nsn.bmp', 0, 0, 0.8, 0.8);
	$worksheet3->set_row(0, 40); # Row 1 height set to 20    	

 	# Write out the data
	    $worksheet3->write(0, 0, 'MONTHLY TICKET REPORT',$title);
    	$worksheet3->write(0, 1, 'Presented by NSN',$title2);
    	$worksheet3->write(0, 2, "$rptmonth \nSt Louis\nEvent Frequency",$wrap2);  	
    	$worksheet3->write(1, 0, 'device_name',$header);
    	$worksheet3->write(1, 1, 'ip_address',  $header);
    	$worksheet3->write(1, 2, 'event_frequency', $header);
    	$worksheet3->write(1, 3, 'non-outage', $header);
    	$worksheet3->write(1, 4, 'outage', $header);
    	$worksheet3->write(1, 5, 'maintenance', $header);
    	$worksheet3->write(1, 6, 'duplicate', $header);
    	$worksheet3->write(1, 7, 'test', $header);
    	$worksheet3->write(1, 8, 'city', $header);
    	$worksheet3->write(1, 9, 'address', $header);
    	$worksheet3->write(1, 10, 'latitude', $header);
    	$worksheet3->write(1, 11, 'longitude', $header);

	$cnt = 0;
	$rowstart = 2;
	#Write out the Excel worksheet
	foreach $ticket (@device_name)
	{
		    $worksheet3->write($rowstart+$cnt, 0, $device_name[$cnt]);
    		$worksheet3->write($rowstart+$cnt, 1, $device_ip[$cnt] );
    		$worksheet3->write($rowstart+$cnt, 2, $event_frequency[$cnt]);
    		$worksheet3->write($rowstart+$cnt, 3, $non_outage[$cnt]);
    		$worksheet3->write($rowstart+$cnt, 4, $outage[$cnt]);
    		$worksheet3->write($rowstart+$cnt, 5, $maintenance[$cnt]);
    		$worksheet3->write($rowstart+$cnt, 6, $duplicate[$cnt]);
    		$worksheet3->write($rowstart+$cnt, 7, $test[$cnt]);
    		$worksheet3->write($rowstart+$cnt, 8, $city[$cnt]);
    		$worksheet3->write($rowstart+$cnt, 9, $address[$cnt]);
    		$worksheet3->write($rowstart+$cnt, 10, $latitude[$cnt]);
    		$worksheet3->write($rowstart+$cnt, 11, $longitude[$cnt]);
    		$cnt = $cnt + 1;
	};
###############################################
##  END St Louis event frequency             ##
###############################################
  

###############################################
##  San Antonio event frequency              ##
###############################################
$cnt = 0;
  @remedy_ticket_number = '';
  @alarm_date = '';
  @status = '';
  @closed_date = '';
  @city = '';
  @address = '';
  @latitude = '';
  @longitude = '';
  @device_name = '';
  @device_ip = '';
  @problem_description = '';
	@error_description = '';
  @summary = '';
  @maintenance = '';
	@outage = '';
	@test = '';
	@non_outage ='';
	@duplicate = '';
	
	$q1 = "SELECT a.customer_id, a.noc_device_name as device_name, b.ip_address, count(*) as event_frequency, b.city, b.address_1, b.latitude, b.longitude FROM tickets a left join devices b on a.noc_device_name = b.noc_device_name where a.customer_name_1 like \'ATT%\' and month(a.create_date) = $rpt_month and year(create_date) = \'2008\' and a.noc_device_name like \'att_st%\' group by b.ip_address order by event_frequency desc";
  $q1 = "SELECT
            a.customer_id,
            a.noc_device_name as device_name,
            b.ip_address, count(*) as event_frequency,
            sum(if(a.summary like \'%Outage: no%\',1,0)) as non_outage,
            sum(if(a.summary like \'%Outage: yes%\',1,0)) as outage,
            sum(if(a.summary like \'%NCR%\',1,0)) as maintenance,
            sum(if(a.summary like \'%Duplicate Alarm: Yes%\',1,0)) as 'duplicate',
            sum(if(a.summary like \'%test%\',1,0)) as test,
            b.city,
            b.address_1,
            b.latitude,
            b.longitude
            FROM tickets a left join devices b on a.noc_device_name = b.noc_device_name
            where a.customer_name_1 like \'ATT%\' and
            month(a.create_date) = $rpt_month and
            year(create_date) = '2009' and
            a.noc_device_name like \'att_sa%\'
            group by b.ip_address order by event_frequency desc";

	#print "\n".$q1."\n";

	# execute the query
	$sth1 = $dbh1->prepare($q1);
	$sth1->execute or die "Unable to execute query";
  
  # populate the array with the node IP values
	while(@row = $sth1->fetchrow_array) {
		$device_name[$cnt] = $row[1];
		$device_ip[$cnt] = $row[2];
		$event_frequency[$cnt] = $row[3];
    $non_outage[$cnt] = $row[4];
    $outage[$cnt] = $row[5];
    $maintenance[$cnt] = $row[6];
    $duplicate[$cnt] = $row[7];
    $test[$cnt] = $row[8];
    if ($row[9] eq "") {$row[9] = "TBD - check device name"};
		$city[$cnt] = $row[9];
		if ($row[10] eq "") {$row[10] = "TBD - check device name"};
		$address[$cnt] = $row[10];
		if ($row[11] eq "") {$row[11] = "TBD - check device name"};
		$latitude[$cnt] = $row[11];
		if ($row[12] eq "") {$row[12] = "TBD - check device name"};
		$longitude[$cnt] = $row[12];

		$cnt = $cnt + 1;
	}
  $recordcnt = $cnt-1;
  
	# Create a new workbook and add a worksheet
    	$worksheet5 = $workbook->add_worksheet("San Antonio Event Freq");

    	# Set the column width for columns
    	$worksheet5->set_column(0, 0, 40); #
    	$worksheet5->set_column(1, 1, 17); # 
    	$worksheet5->set_column(2, 2, 21); # 
    	$worksheet5->set_column(3, 3, 17); # 
    	$worksheet5->set_column(4, 4, 10); #
    	$worksheet5->set_column(5, 5, 15); #
    	$worksheet5->set_column(6, 6, 11); #
    	$worksheet5->set_column(7, 7, 8); #
    	$worksheet5->set_column(8, 8, 20); #
    	$worksheet5->set_column(9, 9, 20); #
    	$worksheet5->set_column(10, 10, 20); #
    	$worksheet5->set_column(11, 11, 20); #
    	$worksheet5->set_column(12, 12, 20); #
    	
    	# Create a format for the column headings
    	$title = $workbook->add_format();
    	$title->set_bold();
    	$title->set_size(16);
    	$title->set_bg_color('aqua');
    	$title->set_color('black');

    	# Create a format for the column headings
    	$title2 = $workbook->add_format();
    	$title2->set_bold();
    	$title2->set_size(8);
    	$title2->set_bg_color('aqua');
    	$title2->set_color('black');

    	# Create a format for the column headings
    	$header = $workbook->add_format();
    	$header->set_bold();
    	$header->set_size(12);
    	$header->set_bg_color('black');
    	$header->set_color('white');

    	$wrap = $workbook->add_format();
    	$wrap->set_text_wrap();

     	$wrap2 = $workbook->add_format();
    	$wrap2->set_bold();
    	$wrap2->set_size(8);
    	$wrap2->set_bg_color('aqua');
    	$wrap2->set_color('black');
    	$wrap2->set_text_wrap();

	# Scale the inserted image: width x 0.4, height x 0.4
	$worksheet5->insert_image('D1', '/home/ggboyden/Documents/perl/nsn.bmp', 0, 0, 0.8, 0.8);
	$worksheet5->set_row(0, 40); # Row 1 height set to 20    	

 	# Write out the data
	    $worksheet5->write(0, 0, 'MONTHLY TICKET REPORT',$title);
    	$worksheet5->write(0, 1, 'Presented by NSN',$title2);
    	$worksheet5->write(0, 2, "$rptmonth \nSan Antonio\nEvent Frequency",$wrap2);  	
    	$worksheet5->write(1, 0, 'device_name',$header);
    	$worksheet5->write(1, 1, 'ip_address',  $header);
    	$worksheet5->write(1, 2, 'event_frequency', $header);
    	$worksheet5->write(1, 3, 'non-outage', $header);
    	$worksheet5->write(1, 4, 'outage', $header);
    	$worksheet5->write(1, 5, 'maintenance', $header);
    	$worksheet5->write(1, 6, 'duplicate', $header);
    	$worksheet5->write(1, 7, 'test', $header);
    	$worksheet5->write(1, 8, 'city', $header);
    	$worksheet5->write(1, 9, 'address', $header);
    	$worksheet5->write(1, 10, 'latitude', $header);
    	$worksheet5->write(1, 11, 'longitude', $header);

	$cnt = 0;
	$rowstart = 2;
	#Write out the Excel worksheet
	foreach $ticket (@device_name)
	{
		    $worksheet5->write($rowstart+$cnt, 0, $device_name[$cnt]);
    		$worksheet5->write($rowstart+$cnt, 1, $device_ip[$cnt] );
    		$worksheet5->write($rowstart+$cnt, 2, $event_frequency[$cnt]);
    		$worksheet5->write($rowstart+$cnt, 3, $non_outage[$cnt]);
    		$worksheet5->write($rowstart+$cnt, 4, $outage[$cnt]);
    		$worksheet5->write($rowstart+$cnt, 5, $maintenance[$cnt]);
    		$worksheet5->write($rowstart+$cnt, 6, $duplicate[$cnt]);
    		$worksheet5->write($rowstart+$cnt, 7, $test[$cnt]);
    		$worksheet5->write($rowstart+$cnt, 8, $city[$cnt]);
    		$worksheet5->write($rowstart+$cnt, 9, $address[$cnt]);
    		$worksheet5->write($rowstart+$cnt, 10, $latitude[$cnt]);
    		$worksheet5->write($rowstart+$cnt, 11, $longitude[$cnt]);
    		$cnt = $cnt + 1;
	};
###############################################
##  END San Antonio event frequency          ##
###############################################

#####################################################
##  Monthly ALL tickets tab                        ##
#####################################################
  $cnt = 0;
  @remedy_ticket_number = '';
  @remedy_ticket_number = '';
  @alarm_date = '';
  @status = '';
  @closed_date = '';
  @city = '';
  @address = '';
  @latitude = '';
  @longitude = '';
  @device_name = '';
  @device_ip = '';
  @problem_description = '';
	@error_description = '';
	@incident_type = '';
  @summary = '';

	$q1 = "SELECT a.customer_id, a.remedy_ticket_id, a.create_date, a.status, a.close_date, b.city, b.address_1, b.latitude, b.longitude, a.noc_device_name as device_name, b.ip_address, a.description, a.error_description, a.summary FROM tickets a left join devices b on a.noc_device_name = b.noc_device_name where a.customer_name_1 like \'ATT%\' and month(a.create_date) = $rpt_month and year(create_date) = $rptyear order by a.create_date";

	# execute the query
	$sth1 = $dbh1->prepare($q1);
	$sth1->execute or die "Unable to execute query";
   
	# populate the array with the node IP values
	while(@row = $sth1->fetchrow_array) {
		$remedy_ticket_number[$cnt] = $row[1];
		$alarm_date[$cnt] = $row[2];
		$status[$cnt] = $row[3];
		$closed_date[$cnt] = $row[4];
		if ($row[5] eq "") {$row[5] = "TBD - check device name"};
		$city[$cnt] = $row[5];
		if ($row[6] eq "") {$row[6] = "TBD - check device name"};
		$address[$cnt] = $row[6];
		if ($row[7] eq "") {$row[7] = "TBD - check device name"};
		$latitude[$cnt] = $row[7];
		if ($row[8] eq "") {$row[8] = "TBD - check device name"};
		$longitude[$cnt] = $row[8];
		if ($row[9] eq "") {$row[9] = "TBD - check device name"};
		$device_name[$cnt] = $row[9];
		if ($row[10] eq "") {$row[10] = "TBD - check device name"};
		$device_ip[$cnt] = $row[10];
		$row[11] =~ s/"//g; # Remove quotes
		if ($row[11] eq "") {$row[11] = "TBD - check device name"};
		$problem_description[$cnt] = $row[11];
		$row[12] =~ s/"//g; # Remove quotes
		$error_description[$cnt] = $row[12];
		$row[13] =~ s/"//g; # Remove quotes

		if ($row[13] eq "") {$row[10] = "Details are being investigated. Summary will be available upon closure of ticket"};
		$summary[$cnt] = $row[13];

		if (length($row[12]) < 2 ) {
			$error_description[$cnt] = $problem_description[$cnt];
		};
		$cnt = $cnt + 1;
	}
  $recordcnt = $cnt;
  
	# Create a new workbook and add a worksheet
    	$worksheet = $workbook->add_worksheet("$rptmonth - $rptyear tickets");

    	# Set the column width for columns
    	$worksheet->set_column(0, 0, 40); #
    	$worksheet->set_column(1, 1, 17); # 
    	$worksheet->set_column(2, 2, 21); # 
    	$worksheet->set_column(3, 3, 17); # 
    	$worksheet->set_column(4, 4, 20); #
    	$worksheet->set_column(5, 5, 30); #
    	$worksheet->set_column(6, 6, 20); #
    	$worksheet->set_column(7, 7, 20); #
    	$worksheet->set_column(8, 8, 25); #
    	$worksheet->set_column(9, 9, 20); #
    	$worksheet->set_column(10, 10, 40); #
    	$worksheet->set_column(11, 11, 30); #
    	$worksheet->set_column(12, 12, 50); #

    	# Create a format for the column headings
    	$title = $workbook->add_format();
    	$title->set_bold();
    	$title->set_size(16);
    	$title->set_bg_color('aqua');
    	$title->set_color('black');

    	# Create a format for the column headings
    	$title2 = $workbook->add_format();
    	$title2->set_bold();
    	$title2->set_size(8);
    	$title2->set_bg_color('aqua');
    	$title2->set_color('black');

    	# Create a format for the column headings
    	$header = $workbook->add_format();
    	$header->set_bold();
    	$header->set_size(12);
    	$header->set_bg_color('black');
    	$header->set_color('white');

    	$wrap = $workbook->add_format();
    	$wrap->set_text_wrap();

     	$wrap2 = $workbook->add_format();
    	$wrap2->set_bold();
    	$wrap2->set_size(8);
    	$wrap2->set_bg_color('aqua');
    	$wrap2->set_color('black');
    	$wrap2->set_text_wrap();

	# Scale the inserted image: width x 0.4, height x 0.4
	$worksheet->insert_image('D1', '/home/ggboyden/Documents/perl/nsn.bmp', 0, 0, 0.8, 0.8);
	$worksheet->set_row(0, 40); # Row 1 height set to 20    	

 	# Write out the data
	$worksheet->write(0, 0, 'MONTHLY TICKET REPORT',$title);
    	$worksheet->write(0, 1, 'Presented by NSN',$title2);
    	$worksheet->write(0, 2, "$rptmonth \nticket_count = $recordcnt",$wrap2);  	
    	$worksheet->write(1, 0, 'remedy_ticket_number',$header);
    	$worksheet->write(1, 1, 'alarm_date',  $header);
    	$worksheet->write(1, 2, 'status', $header);
    	$worksheet->write(1, 3, 'closed_date', $header);
    	$worksheet->write(1, 4, 'city', $header);
    	$worksheet->write(1, 5, 'address', $header);
    	$worksheet->write(1, 6, 'latitude', $header);
    	$worksheet->write(1, 7, 'longitude', $header);
    	$worksheet->write(1, 8, 'device_name', $header);
    	$worksheet->write(1, 9, 'device_ip', $header);
    	$worksheet->write(1, 10, 'error_description', $header);
    	$worksheet->write(1, 11, 'incident_type', $header);
      $worksheet->write(1, 12, 'summary', $header);

	$cnt = 0;
	$rowstart = 2;
	#Write out the Excel worksheet
	foreach $ticket (@remedy_ticket_number)
	{
    		$worksheet->write($rowstart+$cnt, 0, $remedy_ticket_number[$cnt]);
    		$worksheet->write($rowstart+$cnt, 1, $alarm_date[$cnt] );
    		$worksheet->write($rowstart+$cnt, 2, $status[$cnt]);
    		$worksheet->write($rowstart+$cnt, 3, $closed_date[$cnt]);
    		$worksheet->write($rowstart+$cnt, 4, $city[$cnt]);
    		$worksheet->write($rowstart+$cnt, 5, $address[$cnt]);
    		$worksheet->write($rowstart+$cnt, 6, $latitude[$cnt]);
    		$worksheet->write($rowstart+$cnt, 7, $longitude[$cnt]);
    		$worksheet->write($rowstart+$cnt, 8, $device_name[$cnt]);
    		$worksheet->write($rowstart+$cnt, 9, $device_ip[$cnt]);
    		$worksheet->write($rowstart+$cnt, 10, $error_description[$cnt]);
        		
        $incident_type[$cnt] = "device unreachable alarm";   #default
        
        if ($error_description[$cnt] =~ /snmp agent down/) {
             $incident_type[$cnt] = "device unreachable alarm";
        };             
        
        if ($error_description[$cnt] =~ /Interface/) {
             $incident_type[$cnt] = "interface down alarm";
        };             

        if ($error_description[$cnt] =~ /card/) {
             $incident_type[$cnt] = "arm card interface alarm";
        };             

        if ($error_description[$cnt] =~ /test/) {
             $incident_type[$cnt] = "test ticket";
        };             

        if ($error_description[$cnt] =~ /is up/) {
             $incident_type[$cnt] = "test ticket";
        };             

        $worksheet->write($rowstart+$cnt, 11, $incident_type[$cnt]);
    		$worksheet->write($rowstart+$cnt, 12, $summary[$cnt]);
 				$cnt = $cnt + 1;
	};
	
	### Write a CSV file also ###

	open (CSVFILE, ">/home/ggboyden/Documents/perl/monthly_ntd_$filename.csv");
	$cnt = 0;

	$csvline = 'remedy_ticket_number,alarm_date,status,closed_date,city,address,latitude,longitude,device_name,device_ip,error_description,summary';
	print CSVFILE "$csvline\n";


	foreach $ticket (@remedy_ticket_number)
	{
		$cnt = $cnt + 1;
		$csvline = '"'.$remedy_ticket_number[$cnt].'"'.',';
    		$csvline = $csvline.'"'.$alarm_date[$cnt].'"'.',';
    		$csvline = $csvline.'"'.$status[$cnt].'"'.',';
    		$csvline = $csvline.'"'.$closed_date[$cnt].'"'.',';
    		$csvline = $csvline.'"'.$city[$cnt].'"'.',';
    		$csvline = $csvline.'"'.$address[$cnt].'"'.',';
    		$csvline = $csvline.'"'.$latitude[$cnt].'"'.',';
    		$csvline = $csvline.'"'.$longitude[$cnt].'"'.',';
    		$csvline = $csvline.'"'.$device_name[$cnt].'"'.',';
    		$csvline = $csvline.'"'.$device_ip[$cnt].'"'.',';
    		$csvline = $csvline.'"'.$error_description[$cnt].'"'.',';
    		$csvline = $csvline.'"'.$summary[$cnt].'"';
		if ($remedy_ticket_number[$cnt]){
			print CSVFILE "$csvline\n";
			#print "$csvline\n";
		}
	};
	close (CSVFILE);
###############################################
##  End Monthly ALL tickets Tab              ##
###############################################


#####################################################
## 	St Louis Tickets tab                           ##
#####################################################
  
  $cnt = 0;
  @remedy_ticket_number = '';
  @remedy_ticket_number = '';
  @alarm_date = '';
  @status = '';
  @closed_date = '';
  @city = '';
  @address = '';
  @latitude = '';
  @longitude = '';
  @device_name = '';
  @device_ip = '';
  @problem_description = '';
	@error_description = '';
	@incident_type = '';
  @summary = '';
	  	
	$q1 = "SELECT a.customer_id, a.remedy_ticket_id, a.create_date, a.status, a.close_date, b.city, b.address_1, b.latitude, b.longitude, a.noc_device_name as device_name, b.ip_address, a.description, a.error_description, a.summary FROM tickets a left join devices b on a.noc_device_name = b.noc_device_name where a.customer_name_1 like \'ATT%\' and month(a.create_date) = $rpt_month and year(create_date) = $rptyear and a.noc_device_name like \'att_st%\' order by a.create_date ";

	#print "\n".$q1."\n";

	# execute the query
	$sth1 = $dbh1->prepare($q1);
	$sth1->execute or die "Unable to execute query";
   
	# populate the array with the node IP values
	while(@row = $sth1->fetchrow_array) {
		$remedy_ticket_number[$cnt] = $row[1];
		$alarm_date[$cnt] = $row[2];
		$status[$cnt] = $row[3];
		$closed_date[$cnt] = $row[4];
		if ($row[5] eq "") {$row[5] = "TBD - check device name"};
		$city[$cnt] = $row[5];
		if ($row[6] eq "") {$row[6] = "TBD - check device name"};
		$address[$cnt] = $row[6];
		if ($row[7] eq "") {$row[7] = "TBD - check device name"};
		$latitude[$cnt] = $row[7];
		if ($row[8] eq "") {$row[8] = "TBD - check device name"};
		$longitude[$cnt] = $row[8];
		if ($row[9] eq "") {$row[9] = "TBD - check device name"};
		$device_name[$cnt] = $row[9];
		if ($row[10] eq "") {$row[10] = "TBD - check device name"};
		$device_ip[$cnt] = $row[10];
		$row[11] =~ s/"//g; # Remove quotes
		if ($row[11] eq "") {$row[11] = "TBD - check device name"};
		$problem_description[$cnt] = $row[11];
		$row[12] =~ s/"//g; # Remove quotes
		$error_description[$cnt] = $row[12];
		$row[13] =~ s/"//g; # Remove quotes

		if ($row[13] eq "") {$row[10] = "Details are being investigated. Summary will be available upon closure of ticket"};
		$summary[$cnt] = $row[13];

		if (length($row[12]) < 2 ) {
			$error_description[$cnt] = $problem_description[$cnt];
		};
		$cnt = $cnt + 1;
	}
  $recordcnt = $cnt;
  
	# Create a new workbook and add a worksheet
    	$worksheet2 = $workbook->add_worksheet("St Louis tickets");

    	# Set the column width for columns
    	$worksheet2->set_column(0, 0, 40); #
    	$worksheet2->set_column(1, 1, 17); # 
    	$worksheet2->set_column(2, 2, 21); # 
    	$worksheet2->set_column(3, 3, 17); # 
    	$worksheet2->set_column(4, 4, 20); #
    	$worksheet2->set_column(5, 5, 30); #
    	$worksheet2->set_column(6, 6, 20); #
    	$worksheet2->set_column(7, 7, 20); #
    	$worksheet2->set_column(8, 8, 25); #
    	$worksheet2->set_column(9, 9, 20); #
    	$worksheet2->set_column(10, 10, 40); #
    	$worksheet2->set_column(11, 11, 30); #
    	$worksheet2->set_column(12, 12, 50); #

    	# Create a format for the column headings
    	$title = $workbook->add_format();
    	$title->set_bold();
    	$title->set_size(16);
    	$title->set_bg_color('aqua');
    	$title->set_color('black');

    	# Create a format for the column headings
    	$title2 = $workbook->add_format();
    	$title2->set_bold();
    	$title2->set_size(8);
    	$title2->set_bg_color('aqua');
    	$title2->set_color('black');

    	# Create a format for the column headings
    	$header = $workbook->add_format();
    	$header->set_bold();
    	$header->set_size(12);
    	$header->set_bg_color('black');
    	$header->set_color('white');

    	$wrap = $workbook->add_format();
    	$wrap->set_text_wrap();

     	$wrap2 = $workbook->add_format();
    	$wrap2->set_bold();
    	$wrap2->set_size(8);
    	$wrap2->set_bg_color('aqua');
    	$wrap2->set_color('black');
    	$wrap2->set_text_wrap();

	# Scale the inserted image: width x 0.4, height x 0.4
	$worksheet2->insert_image('D1', '/home/ggboyden/Documents/perl/nsn.bmp', 0, 0, 0.8, 0.8);
	$worksheet2->set_row(0, 40); # Row 1 height set to 20    	

  	# Write out the data
	    $worksheet2->write(0, 0, 'MONTHLY TICKET REPORT',$title);
    	$worksheet2->write(0, 1, 'Presented by NSN',$title2);
    	$worksheet2->write(0, 2, "$rptmonth \nticket_count = $recordcnt",$wrap2);  	
    	$worksheet2->write(1, 0, 'remedy_ticket_number',$header);
    	$worksheet2->write(1, 1, 'alarm_date',  $header);
    	$worksheet2->write(1, 2, 'status', $header);
    	$worksheet2->write(1, 3, 'closed_date', $header);
    	$worksheet2->write(1, 4, 'city', $header);
    	$worksheet2->write(1, 5, 'address', $header);
    	$worksheet2->write(1, 6, 'latitude', $header);
    	$worksheet2->write(1, 7, 'longitude', $header);
    	$worksheet2->write(1, 8, 'device_name', $header);
    	$worksheet2->write(1, 9, 'device_ip', $header);
    	$worksheet2->write(1, 10, 'error_description', $header);
    	$worksheet2->write(1, 11, 'incident_type', $header);
      $worksheet2->write(1, 12, 'summary', $header);

	$cnt = 0;
	$rowstart = 2;
	#Write out the Excel worksheet
	foreach $ticket (@remedy_ticket_number)
	{
    		$worksheet2->write($rowstart+$cnt, 0, $remedy_ticket_number[$cnt]);
    		$worksheet2->write($rowstart+$cnt, 1, $alarm_date[$cnt] );
    		$worksheet2->write($rowstart+$cnt, 2, $status[$cnt]);
    		$worksheet2->write($rowstart+$cnt, 3, $closed_date[$cnt]);
    		$worksheet2->write($rowstart+$cnt, 4, $city[$cnt]);
    		$worksheet2->write($rowstart+$cnt, 5, $address[$cnt]);
    		$worksheet2->write($rowstart+$cnt, 6, $latitude[$cnt]);
    		$worksheet2->write($rowstart+$cnt, 7, $longitude[$cnt]);
    		$worksheet2->write($rowstart+$cnt, 8, $device_name[$cnt]);
    		$worksheet2->write($rowstart+$cnt, 9, $device_ip[$cnt]);
    		$worksheet2->write($rowstart+$cnt, 10, $error_description[$cnt]);
    		
        $incident_type[$cnt] = "device unreachable alarm";   #default
        
        if ($error_description[$cnt] =~ /snmp agent down/) {
             $incident_type[$cnt] = "device unreachable alarm";
        };             
        
        if ($error_description[$cnt] =~ /Interface/) {
             $incident_type[$cnt] = "interface down alarm";
        };             

        if ($error_description[$cnt] =~ /card/) {
             $incident_type[$cnt] = "arm card interface alarm";
        };             

        if ($error_description[$cnt] =~ /test/) {
             $incident_type[$cnt] = "test ticket";
        };             

        if ($error_description[$cnt] =~ /is up/) {
             $incident_type[$cnt] = "test ticket";
        };             
             
        $worksheet2->write($rowstart+$cnt, 11, $incident_type[$cnt]);
    		$worksheet2->write($rowstart+$cnt, 12, $summary[$cnt]);
 				$cnt = $cnt + 1;
	};

###############################################
##  End St Louis tickets Tab                 ##
###############################################

###############################################
##  San Antonio Tickets                      ##
###############################################
 
  $cnt = 0;
  @remedy_ticket_number = '';
  @remedy_ticket_number = '';
  @alarm_date = '';
  @status = '';
  @closed_date = '';
  @city = '';
  @address = '';
  @latitude = '';
  @longitude = '';
  @device_name = '';
  @device_ip = '';
  @problem_description = '';
	@error_description = '';
	@incident_type = '';
  @summary = '';
	  	
	$q1 = "SELECT a.customer_id, a.remedy_ticket_id, a.create_date, a.status, a.close_date, b.city, b.address_1, b.longitude, b.latitude, a.noc_device_name as device_name, b.ip_address, a.description, a.error_description, a.summary FROM tickets a left join devices b on a.noc_device_name = b.noc_device_name where a.customer_name_1 like \'ATT%\' and month(a.create_date) = $rpt_month and year(create_date) = $rptyear and a.noc_device_name like \'att_sa%\' order by a.create_date ";

	#print "\n".$q1."\n";

	# execute the query
	$sth1 = $dbh1->prepare($q1);
	$sth1->execute or die "Unable to execute query";
   
	# populate the array with the node IP values
	while(@row = $sth1->fetchrow_array) {
		$remedy_ticket_number[$cnt] = $row[1];
		$alarm_date[$cnt] = $row[2];
		$status[$cnt] = $row[3];
		$closed_date[$cnt] = $row[4];
		if ($row[5] eq "") {$row[5] = "TBD - check device name"};
		$city[$cnt] = $row[5];
		if ($row[6] eq "") {$row[6] = "TBD - check device name"};
		$address[$cnt] = $row[6];
		if ($row[7] eq "") {$row[7] = "TBD - check device name"};
		$latitude[$cnt] = $row[7];
		if ($row[8] eq "") {$row[8] = "TBD - check device name"};
		$longitude[$cnt] = $row[8];
		if ($row[9] eq "") {$row[9] = "TBD - check device name"};
		$device_name[$cnt] = $row[9];
		if ($row[10] eq "") {$row[10] = "TBD - check device name"};
		$device_ip[$cnt] = $row[10];
		$row[11] =~ s/"//g; # Remove quotes
		if ($row[11] eq "") {$row[11] = "TBD - check device name"};
		$problem_description[$cnt] = $row[11];
		$row[12] =~ s/"//g; # Remove quotes
		$error_description[$cnt] = $row[12];
		$row[13] =~ s/"//g; # Remove quotes

		if ($row[13] eq "") {$row[10] = "Details are being investigated. Summary will be available upon closure of ticket"};
		$summary[$cnt] = $row[13];

		if (length($row[12]) < 2 ) {
			$error_description[$cnt] = $problem_description[$cnt];
		};
		$cnt = $cnt + 1;
	}
  $recordcnt = $cnt;
  
	# Create a new workbook and add a worksheet
    	$worksheet4 = $workbook->add_worksheet("San Antonio tickets");

    	# Set the column width for columns
    	$worksheet4->set_column(0, 0, 40); #
    	$worksheet4->set_column(1, 1, 17); # 
    	$worksheet4->set_column(2, 2, 21); # 
    	$worksheet4->set_column(3, 3, 17); # 
    	$worksheet4->set_column(4, 4, 20); #
    	$worksheet4->set_column(5, 5, 30); #
    	$worksheet4->set_column(6, 6, 20); #
    	$worksheet4->set_column(7, 7, 20); #
    	$worksheet4->set_column(8, 8, 25); #
    	$worksheet4->set_column(9, 9, 20); #
    	$worksheet4->set_column(10, 10, 40); #
    	$worksheet4->set_column(11, 11, 30); #    	
      $worksheet4->set_column(12, 12, 50); #

    	# Create a format for the column headings
    	$title = $workbook->add_format();
    	$title->set_bold();
    	$title->set_size(16);
    	$title->set_bg_color('aqua');
    	$title->set_color('black');

    	# Create a format for the column headings
    	$title2 = $workbook->add_format();
    	$title2->set_bold();
    	$title2->set_size(8);
    	$title2->set_bg_color('aqua');
    	$title2->set_color('black');

    	# Create a format for the column headings
    	$header = $workbook->add_format();
    	$header->set_bold();
    	$header->set_size(12);
    	$header->set_bg_color('black');
    	$header->set_color('white');

    	$wrap = $workbook->add_format();
    	$wrap->set_text_wrap();

     	$wrap2 = $workbook->add_format();
    	$wrap2->set_bold();
    	$wrap2->set_size(8);
    	$wrap2->set_bg_color('aqua');
    	$wrap2->set_color('black');
    	$wrap2->set_text_wrap();

	# Scale the inserted image: width x 0.4, height x 0.4
	$worksheet4->insert_image('D1', '/home/ggboyden/Documents/perl/nsn.bmp', 0, 0, 0.8, 0.8);
	$worksheet4->set_row(0, 40); # Row 1 height set to 40    	

 	# Write out the data
	    $worksheet4->write(0, 0, 'MONTHLY TICKET REPORT',$title);
    	$worksheet4->write(0, 1, 'Presented by NSN',$title2);
    	$worksheet4->write(0, 2, "$rptmonth \nticket_count = $recordcnt",$wrap2);  	
    	$worksheet4->write(1, 0, 'remedy_ticket_number',$header);
    	$worksheet4->write(1, 1, 'alarm_date',  $header);
    	$worksheet4->write(1, 2, 'status', $header);
    	$worksheet4->write(1, 3, 'closed_date', $header);
    	$worksheet4->write(1, 4, 'city', $header);
    	$worksheet4->write(1, 5, 'address', $header);
    	$worksheet4->write(1, 6, 'latitude', $header);
    	$worksheet4->write(1, 7, 'longitude', $header);
    	$worksheet4->write(1, 8, 'device_name', $header);
    	$worksheet4->write(1, 9, 'device_ip', $header);
    	$worksheet4->write(1, 10, 'error_description', $header);
    	$worksheet4->write(1, 11, 'incident_type', $header);    	
    	$worksheet4->write(1, 12, 'summary', $header);

	$cnt = 0;
	$rowstart = 2;
	#Write out the Excel worksheet
	foreach $ticket (@remedy_ticket_number)
	{
    		$worksheet4->write($rowstart+$cnt, 0, $remedy_ticket_number[$cnt]);
    		$worksheet4->write($rowstart+$cnt, 1, $alarm_date[$cnt] );
    		$worksheet4->write($rowstart+$cnt, 2, $status[$cnt]);
    		$worksheet4->write($rowstart+$cnt, 3, $closed_date[$cnt]);
    		$worksheet4->write($rowstart+$cnt, 4, $city[$cnt]);
    		$worksheet4->write($rowstart+$cnt, 5, $address[$cnt]);
    		$worksheet4->write($rowstart+$cnt, 6, $latitude[$cnt]);
    		$worksheet4->write($rowstart+$cnt, 7, $longitude[$cnt]);
    		$worksheet4->write($rowstart+$cnt, 8, $device_name[$cnt]);
    		$worksheet4->write($rowstart+$cnt, 9, $device_ip[$cnt]);
    		$worksheet4->write($rowstart+$cnt, 10, $error_description[$cnt]);

        $incident_type[$cnt] = "device unreachable alarm";   #default
        
        if ($error_description[$cnt] =~ /snmp agent down/) {
             $incident_type[$cnt] = "device unreachable alarm";
        };             
        
        if ($error_description[$cnt] =~ /Interface/) {
             $incident_type[$cnt] = "interface down alarm";
        };             

        if ($error_description[$cnt] =~ /card/) {
             $incident_type[$cnt] = "arm card interface alarm";
        };             

        if ($error_description[$cnt] =~ /test/) {
             $incident_type[$cnt] = "test ticket";
        };             

        if ($error_description[$cnt] =~ /is up/) {
             $incident_type[$cnt] = "test ticket";
        };             

        $worksheet4->write($rowstart+$cnt, 11, $incident_type[$cnt]);
    		$worksheet4->write($rowstart+$cnt, 12, $summary[$cnt]);
 				$cnt = $cnt + 1;
	};
###############################################
##  End San Antonio Tickets                  ##
###############################################

###############################################
##  Riverside Tickets                        ##
###############################################
 
  $cnt = 0;
  @remedy_ticket_number = '';
  @remedy_ticket_number = '';
  @alarm_date = '';
  @status = '';
  @closed_date = '';
  @city = '';
  @address = '';
  @latitude = '';
  @longitude = '';
  @device_name = '';
  @device_ip = '';
  @problem_description = '';
	@error_description = '';
	@incident_type = '';
  @summary = '';
	  	
	$q1 = "SELECT a.customer_id, a.remedy_ticket_id, a.create_date, a.status, a.close_date, b.city, b.address_1, b.longitude, b.latitude, a.noc_device_name as device_name, b.ip_address, a.description, a.error_description, a.summary FROM tickets a left join devices b on a.noc_device_name = b.noc_device_name where a.customer_name_1 like \'ATT%\' and month(a.create_date) = $rpt_month and year(create_date) = $rptyear and a.noc_device_name like \'att_ri%\' order by a.create_date ";

	#print "\n".$q1."\n";

	# execute the query
	$sth1 = $dbh1->prepare($q1);
	$sth1->execute or die "Unable to execute query";
   
	# populate the array with the node IP values
	while(@row = $sth1->fetchrow_array) {
		$remedy_ticket_number[$cnt] = $row[1];
		$alarm_date[$cnt] = $row[2];
		$status[$cnt] = $row[3];
		$closed_date[$cnt] = $row[4];
		if ($row[5] eq "") {$row[5] = "TBD - check device name"};
		$city[$cnt] = $row[5];
		if ($row[6] eq "") {$row[6] = "TBD - check device name"};
		$address[$cnt] = $row[6];
		if ($row[7] eq "") {$row[7] = "TBD - check device name"};
		$latitude[$cnt] = $row[7];
		if ($row[8] eq "") {$row[8] = "TBD - check device name"};
		$longitude[$cnt] = $row[8];
		if ($row[9] eq "") {$row[9] = "TBD - check device name"};
		$device_name[$cnt] = $row[9];
		if ($row[10] eq "") {$row[10] = "TBD - check device name"};
		$device_ip[$cnt] = $row[10];
		$row[11] =~ s/"//g; # Remove quotes
		if ($row[11] eq "") {$row[11] = "TBD - check device name"};
		$problem_description[$cnt] = $row[11];
		$row[12] =~ s/"//g; # Remove quotes
		$error_description[$cnt] = $row[12];
		$row[13] =~ s/"//g; # Remove quotes

		if ($row[13] eq "") {$row[10] = "Details are being investigated. Summary will be available upon closure of ticket"};
		$summary[$cnt] = $row[13];

		if (length($row[12]) < 2 ) {
			$error_description[$cnt] = $problem_description[$cnt];
		};
		$cnt = $cnt + 1;
	}
  $recordcnt = $cnt;
  
	# Create a new workbook and add a worksheet
    	$worksheet6 = $workbook->add_worksheet("Riverside tickets");

    	# Set the column width for columns
    	$worksheet6->set_column(0, 0, 40); #
    	$worksheet6->set_column(1, 1, 17); # 
    	$worksheet6->set_column(2, 2, 21); # 
    	$worksheet6->set_column(3, 3, 17); # 
    	$worksheet6->set_column(4, 4, 20); #
    	$worksheet6->set_column(5, 5, 30); #
    	$worksheet6->set_column(6, 6, 20); #
    	$worksheet6->set_column(7, 7, 20); #
    	$worksheet6->set_column(8, 8, 25); #
    	$worksheet6->set_column(9, 9, 20); #
    	$worksheet6->set_column(10, 10, 40); #
    	$worksheet6->set_column(11, 11, 30); #
    	$worksheet6->set_column(12, 12, 50); #

    	# Create a format for the column headings
    	$title = $workbook->add_format();
    	$title->set_bold();
    	$title->set_size(16);
    	$title->set_bg_color('aqua');
    	$title->set_color('black');

    	# Create a format for the column headings
    	$title2 = $workbook->add_format();
    	$title2->set_bold();
    	$title2->set_size(8);
    	$title2->set_bg_color('aqua');
    	$title2->set_color('black');

    	# Create a format for the column headings
    	$header = $workbook->add_format();
    	$header->set_bold();
    	$header->set_size(12);
    	$header->set_bg_color('black');
    	$header->set_color('white');

    	$wrap = $workbook->add_format();
    	$wrap->set_text_wrap();

     	$wrap2 = $workbook->add_format();
    	$wrap2->set_bold();
    	$wrap2->set_size(8);
    	$wrap2->set_bg_color('aqua');
    	$wrap2->set_color('black');
    	$wrap2->set_text_wrap();

	# Scale the inserted image: width x 0.4, height x 0.4
	$worksheet6->insert_image('D1', '/home/ggboyden/Documents/perl/nsn.bmp', 0, 0, 0.8, 0.8);
	$worksheet6->set_row(0, 40); # Row 1 height set to 20    	

 	# Write out the data
	    $worksheet6->write(0, 0, 'MONTHLY TICKET REPORT',$title);
    	$worksheet6->write(0, 1, 'Presented by NSN',$title2);
    	$worksheet6->write(0, 2, "$rptmonth \nticket_count = $recordcnt",$wrap2);  	
    	$worksheet6->write(1, 0, 'remedy_ticket_number',$header);
    	$worksheet6->write(1, 1, 'alarm_date',  $header);
    	$worksheet6->write(1, 2, 'status', $header);
    	$worksheet6->write(1, 3, 'closed_date', $header);
    	$worksheet6->write(1, 4, 'city', $header);
    	$worksheet6->write(1, 5, 'address', $header);
    	$worksheet6->write(1, 6, 'latitude', $header);
    	$worksheet6->write(1, 7, 'longitude', $header);
    	$worksheet6->write(1, 8, 'device_name', $header);
    	$worksheet6->write(1, 9, 'device_ip', $header);
    	$worksheet6->write(1, 10, 'error_description', $header);
    	$worksheet6->write(1, 11, 'incident_type', $header);
    	$worksheet6->write(1, 12, 'summary', $header);

	$cnt = 0;
	$rowstart = 2;
	#Write out the Excel worksheet
	foreach $ticket (@remedy_ticket_number)
	{
    		$worksheet6->write($rowstart+$cnt, 0, $remedy_ticket_number[$cnt]);
    		$worksheet6->write($rowstart+$cnt, 1, $alarm_date[$cnt] );
    		$worksheet6->write($rowstart+$cnt, 2, $status[$cnt]);
    		$worksheet6->write($rowstart+$cnt, 3, $closed_date[$cnt]);
    		$worksheet6->write($rowstart+$cnt, 4, $city[$cnt]);
    		$worksheet6->write($rowstart+$cnt, 5, $address[$cnt]);
    		$worksheet6->write($rowstart+$cnt, 6, $latitude[$cnt]);
    		$worksheet6->write($rowstart+$cnt, 7, $longitude[$cnt]);
    		$worksheet6->write($rowstart+$cnt, 8, $device_name[$cnt]);
    		$worksheet6->write($rowstart+$cnt, 9, $device_ip[$cnt]);
    		$worksheet6->write($rowstart+$cnt, 10, $error_description[$cnt]);
        $incident_type[$cnt] = "device unreachable alarm";   #default
        
        if ($error_description[$cnt] =~ /snmp agent down/) {
             $incident_type[$cnt] = "device unreachable alarm";
        };             
        
        if ($error_description[$cnt] =~ /Interface/) {
             $incident_type[$cnt] = "interface down alarm";
        };             

        if ($error_description[$cnt] =~ /card/) {
             $incident_type[$cnt] = "arm card interface alarm";
        };             

        if ($error_description[$cnt] =~ /test/) {
             $incident_type[$cnt] = "test ticket";
        };             

        if ($error_description[$cnt] =~ /is up/) {
             $incident_type[$cnt] = "test ticket";
        };             
        $worksheet6->write($rowstart+$cnt, 11, $incident_type[$cnt]);
    		$worksheet6->write($rowstart+$cnt, 11, $summary[$cnt]);
 				$cnt = $cnt + 1;
	};
###############################################
##  END Riverside Tickets                    ##
###############################################

###############################################
##  Riverside event frequency                ##
###############################################
  $cnt = 0;
  @remedy_ticket_number = '';
  @alarm_date = '';
  @status = '';
  @closed_date = '';
  @city = '';
  @address = '';
  @latitude = '';
  @longitude = '';
  @device_name = '';
  @device_ip = '';
  @problem_description = '';
	@error_description = '';
  @summary = '';
  @maintenance = '';
	@outage = '';
	@test = '';
	@non_outage ='';
	@duplicate = '';
	
	$q1 = "SELECT a.customer_id, a.noc_device_name as device_name, b.ip_address, count(*) as event_frequency, b.city, b.address_1, b.latitude, b.longitude FROM tickets a left join devices b on a.noc_device_name = b.noc_device_name where a.customer_name_1 like \'ATT%\' and month(a.create_date) = $rpt_month and year(create_date) = \'2008\' and a.noc_device_name like \'att_st%\' group by b.ip_address order by event_frequency desc";
  $q1 = "SELECT
            a.customer_id,
            a.noc_device_name as device_name,
            b.ip_address, count(*) as event_frequency,
            sum(if(a.summary like \'%Outage: no%\',1,0)) as non_outage,
            sum(if(a.summary like \'%Outage: yes%\',1,0)) as outage,
            sum(if(a.summary like \'%NCR%\',1,0)) as maintenance,
            sum(if(a.summary like \'%Duplicate Alarm: Yes%\',1,0)) as 'duplicate',
            sum(if(a.summary like \'%test%\',1,0)) as test,
            b.city,
            b.address_1,
            b.latitude,
            b.longitude
            FROM tickets a left join devices b on a.noc_device_name = b.noc_device_name
            where a.customer_name_1 like \'ATT%\' and
            month(a.create_date) = $rpt_month and
            year(create_date) = '2009' and
            a.noc_device_name like \'att_ri%\'
            group by b.ip_address order by event_frequency desc";

	#print "\n".$q1."\n";

	# execute the query
	$sth1 = $dbh1->prepare($q1);
	$sth1->execute or die "Unable to execute query";
  
  # populate the array with the node IP values
	while(@row = $sth1->fetchrow_array) {
		$device_name[$cnt] = $row[1];
		$device_ip[$cnt] = $row[2];
		$event_frequency[$cnt] = $row[3];
    $non_outage[$cnt] = $row[4];
    $outage[$cnt] = $row[5];
    $maintenance[$cnt] = $row[6];
    $duplicate[$cnt] = $row[7];
    $test[$cnt] = $row[8];
    if ($row[9] eq "") {$row[9] = "TBD - check device name"};
		$city[$cnt] = $row[9];
		if ($row[10] eq "") {$row[10] = "TBD - check device name"};
		$address[$cnt] = $row[10];
		if ($row[11] eq "") {$row[11] = "TBD - check device name"};
		$latitude[$cnt] = $row[11];
		if ($row[12] eq "") {$row[12] = "TBD - check device name"};
		$longitude[$cnt] = $row[12];

		$cnt = $cnt + 1;
	}
  $recordcnt = $cnt-1;
  
	# Create a new workbook and add a worksheet
    	$worksheet7 = $workbook->add_worksheet("Riverside Event Freq");

    	# Set the column width for columns
    	$worksheet7->set_column(0, 0, 40); #
    	$worksheet7->set_column(1, 1, 17); # 
    	$worksheet7->set_column(2, 2, 21); # 
    	$worksheet7->set_column(3, 3, 17); # 
    	$worksheet7->set_column(4, 4, 10); #
    	$worksheet7->set_column(5, 5, 15); #
    	$worksheet7->set_column(6, 6, 11); #
    	$worksheet7->set_column(7, 7, 8); #
    	$worksheet7->set_column(8, 8, 20); #
    	$worksheet7->set_column(9, 9, 20); #
    	$worksheet7->set_column(10, 10, 20); #
    	$worksheet7->set_column(11, 11, 20); #
    	$worksheet7->set_column(12, 12, 20); #
    	
    	# Create a format for the column headings
    	$title = $workbook->add_format();
    	$title->set_bold();
    	$title->set_size(16);
    	$title->set_bg_color('aqua');
    	$title->set_color('black');

    	# Create a format for the column headings
    	$title2 = $workbook->add_format();
    	$title2->set_bold();
    	$title2->set_size(8);
    	$title2->set_bg_color('aqua');
    	$title2->set_color('black');

    	# Create a format for the column headings
    	$header = $workbook->add_format();
    	$header->set_bold();
    	$header->set_size(12);
    	$header->set_bg_color('black');
    	$header->set_color('white');

    	$wrap = $workbook->add_format();
    	$wrap->set_text_wrap();

     	$wrap2 = $workbook->add_format();
    	$wrap2->set_bold();
    	$wrap2->set_size(8);
    	$wrap2->set_bg_color('aqua');
    	$wrap2->set_color('black');
    	$wrap2->set_text_wrap();

	# Scale the inserted image: width x 0.4, height x 0.4
	$worksheet7->insert_image('D1', '/home/ggboyden/Documents/perl/nsn.bmp', 0, 0, 0.8, 0.8);
	$worksheet7->set_row(0, 40); # Row 1 height set to 20    	

 	# Write out the data
	    $worksheet7->write(0, 0, 'MONTHLY TICKET REPORT',$title);
    	$worksheet7->write(0, 1, 'Presented by NSN',$title2);
    	$worksheet7->write(0, 2, "$rptmonth \nRiverside\nEvent Frequency",$wrap2);  	
    	$worksheet7->write(1, 0, 'device_name',$header);
    	$worksheet7->write(1, 1, 'ip_address',  $header);
    	$worksheet7->write(1, 2, 'event_frequency', $header);
    	$worksheet7->write(1, 3, 'non-outage', $header);
    	$worksheet7->write(1, 4, 'outage', $header);
    	$worksheet7->write(1, 5, 'maintenance', $header);
    	$worksheet7->write(1, 6, 'duplicate', $header);
    	$worksheet7->write(1, 7, 'test', $header);
    	$worksheet7->write(1, 8, 'city', $header);
    	$worksheet7->write(1, 9, 'address', $header);
    	$worksheet7->write(1, 10, 'latitude', $header);
    	$worksheet7->write(1, 11, 'longitude', $header);

	$cnt = 0;
	$rowstart = 2;
	#Write out the Excel worksheet
	foreach $ticket (@device_name)
	{
		    $worksheet7->write($rowstart+$cnt, 0, $device_name[$cnt]);
    		$worksheet7->write($rowstart+$cnt, 1, $device_ip[$cnt] );
    		$worksheet7->write($rowstart+$cnt, 2, $event_frequency[$cnt]);
    		$worksheet7->write($rowstart+$cnt, 3, $non_outage[$cnt]);
    		$worksheet7->write($rowstart+$cnt, 4, $outage[$cnt]);
    		$worksheet7->write($rowstart+$cnt, 5, $maintenance[$cnt]);
    		$worksheet7->write($rowstart+$cnt, 6, $duplicate[$cnt]);
    		$worksheet7->write($rowstart+$cnt, 7, $test[$cnt]);
    		$worksheet7->write($rowstart+$cnt, 8, $city[$cnt]);
    		$worksheet7->write($rowstart+$cnt, 9, $address[$cnt]);
    		$worksheet7->write($rowstart+$cnt, 10, $latitude[$cnt]);
    		$worksheet7->write($rowstart+$cnt, 11, $longitude[$cnt]);
    		$cnt = $cnt + 1;
	};###############################################
##  END Riverside event frequency            ##
###############################################


###################################
  ### End sub-tab reports ###

  $workbook->close();
	$sth1->finish;
  $rpt_month = $rpt_month + 1;	
}  
	print "Disconnecting from NOC database\n";
	$dbh1->disconnect;
                   
  exit;                 	
	### Send Files as E-Mail ###

  system ("zip /home/ggboyden/Documents/perl/monthly_ntr_$filename.zip /home/ggboyden/Documents/perl/monthly_ntr_$filename.xls");
  sleep 2;
  system ("zip /home/ggboyden/Documents/perl/monthly_ntd_$filename.zip /home/ggboyden/Documents/perl/monthly_ntd_$filename.csv");

	#my $sendToAddress = 'netopscenter.us@siemens.com, dg.nsn_report_att_wifi@nokia.com, dpark@belairnetworks.com, techsupport@belairnetworks.com, alexander.mizzi@siemens.com, laura.h.martinez@siemens.com,debbie.white@siemens.com,glenn.boyden@siemens.com';
	#my $sendToAddress = 'netopscenter.us@siemens.com,
  #                     nsn-notification-att-wifi@mlist.nsn-inter.net,
  #                     nsn-report-att-wifi@mlist.nsn-inter.net,
  #                     nsn-escalation-att-wifi@mlist.nsn-inter.net,
  #                     dg.nsn_report_att_wifi@nokia.com,
  #                     techsupport@belairnetworks.com, 
  #                     alexander.mizzi@siemens.com, 
  #                     laura.h.martinez@siemens.com,
  #                     glenn.boyden@siemens.com';
	my $sendToAddress = 'dfw8888@yahoo.com, glenn.boyden@siemens-enterprise.com';
	my $myEmailAddress = 'netopscenter.us@siemens.com';
	my $attachment1 = "/home/ggboyden/Documents/perl/monthly_ntr_$filename.zip";
	my $attachment2 = "/home/ggboyden/Documents/perl/monthly_ntd_$filename.zip";
	my $mail;

	### Create Mail Header
	$mail = MIME::Entity->build(Type =>"multipart/mixed", 
			From =>$myEmailAddress,
			To =>$sendToAddress,
			Subject => "ATT Monthly Ticket Report for $rptmonth");

	### Add Attachement 1 (the body)
	$body = "Please find the attached dump(csv) and report(xls) files for $rptmonth\n";
	$body = $body."This is an automatically created e-mail.\n";

	$mail->attach(
   			Type     => 'TEXT',
		    	Data     => $body
	);

	### Add Attachement 2 (the excel file)
	$mail->attach(Path => $attachment1, Type => "image/gif", Encoding => "base64");

	### Add Attachement 2 (the csv file)
	$mail->attach(Path => $attachment2, Type => "image/gif", Encoding => "base64");

	### Send the message with attachment
	open MAIL,"|/usr/lib/sendmail -t -oi -oem" or die"open: $!";
	$mail ->print(\*MAIL);
	close MAIL;


 ### SCP files to the WIP server ENNOC / $report%
 my $scpe = Net::SCP::Expect->new(host=>'10.0.90.248', user=>'ENNOC', password=>'$report%');
 $scpe->scp("$attachment1","/opt/reports/in"); # 'file' copied to 'host' at '/some/dir'
 $scpe->scp("$attachment2","/opt/reports/in"); # 'file' copied to 'host' at '/some/dir'

 sleep(5); #wait for xfer to complete
### Delete the excel file so they do not take up room. 
#	unlink($attachment1);
#	unlink($attachment2);
	exit;
	

