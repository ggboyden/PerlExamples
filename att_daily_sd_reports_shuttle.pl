#!/usr/bin/perl -w
# ****************************************************************
#   Written by Glenn Boyden
#   Last updated on 8/16/2008
#   Description:  This perl script will move the Service Desk Excel
#   reports from sftp.siemensnoc.net to  WIP ENNOC 
# ****************************************************************

  use strict;
  use Time::Local; 
  use Date::Format;
  use Time::Interval;
  use Spreadsheet::WriteExcel;
  use Net::SCP::Expect;
  use MIME::Entity;


 ### SCP files from the NOC sftp.siemensnoc.net server
 my $scpe_nocsftp = Net::SCP::Expect->new(auto_yes=>1, host=>'172.16.20.114', user=>'Service_Desk', password=>'service_desk123');
    $scpe_nocsftp->scp(':*.xls','/home/ggboyden/Documents/perl/sd_reports'); # 'file' copied to 'host' at '/some/dir'
 sleep(5); #wait for xfer to complete

 ### SCP files to the WIP server ENNOC / $report%
 my $scpe_wip = Net::SCP::Expect->new(auto_yes=>1, host=>'10.0.90.248', user=>'ENNOC', password=>'$report%');
    $scpe_wip->scp('/home/ggboyden/Documents/perl/daily_acd_20080821.xls',"/opt/reports/in"); # 'file' copied to 'host' at '/some/dir'
                                     
 sleep(5); #wait for xfer to complete
### Delete the excel file so they do not take up room. 
#	unlink($attachment1);
#	unlink($attachment2);
	exit;

