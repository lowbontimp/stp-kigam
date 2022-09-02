#!/usr/bin/env perl

use strict ;
use warnings ;
use Term::ReadLine;
use LWP::UserAgent ;
use HTTP::Request ;
use Date::Calc::XS ;
use IO::Uncompress::Unzip qw(unzip $UnzipError) ;
use File::Path qw (make_path) ;
use Time::HiRes qw (gettimeofday tv_interval usleep) ;

my $version = "1.00" ;

#my $sac = "/home/hbim/downloads/SAC101.6a/etc/sac-101.6a/build/bin/sac" ;
my $sac = "sac" ;

#my $parameterfilename = "./parameter.dat" ;
#my $taup     =&getscalar($parameterfilename,"taup") ;

my $re="(?:(?i)(?:[-+]?)(?:(?=[.]?[0123456789])(?:[0123456789]*)(?:(?:[.])(?:[0123456789]{0,}))?)(?:(?:[E])(?:(?:[-+]?)(?:[0123456789]+))|))"; # regular expression for general real number.
my $int = "(?:(?:[-+]?)(?:[0123456789]+))";
my $prompt="STP) ";
my $logfile="./STP.log";
#my $logfile="/dev/null";
my $omarker=0;
my $outputdir=".";
my $outputdir_resp = "." ;
my $decimation="off";
my @factors = ();
my $tmpdir="./.tmpdir.aJyrZ0RjID782P89";
#my $velocitymodel="ak135";
my ($phasename1_g,$trvt1_g,$phasename2_g,$trvt2_g)=(-12345,-12345,-12345,-12345);
my ($evla_g,$evlo_g,$evdp_g)=(-12345,-12345,-12345);
my ($evmag_g,$evmagtyp_g) = (-12345,-12345);
my $outputfilename="0";
my $verbose=1; # 1 or 0;
my $skip = "off"; #on or off
my $skipresp = "on" ; #skip if the response file exists

#rate of connection
my $sleeping_time = 1e6*0.5 ; #microsecond
my $number_averaged = 5 ; #5 is recommended
my $rate_threshold = 5.0 ; #should be <10.0 number/s
my @times ;
my $t0 = [gettimeofday] ;

#box option for searching the stations. no space is allowed
my $box = "&minlat=-90&maxlat=90&minlon=-180&maxlon=180" ; #global

#my $token = "M6DZARQiX60...something like it" ;
#my $token = "" ;

my $token = &read_token() ;

#my $box ;
#$box .= "&minlat=38.8533" ;
#$box .= "&maxlat=51.149" ;
#$box .= "&minlon=-134.0732" ;
#$box .= "&maxlon=-122.3837" ;


#main
&mkTmpDir();
&initialMsg();
&waiting();


sub evt_single {
	my ($ymdhms,$net,$sta,$loc,$comp,$winformat1,$winformat2)=@_;
	
	#if ( ($skip eq "on") and (-e $outputfilename) ){
	#print "path: $outputdir/$outputfilename\n" ;
	#if ( ($skip eq "on") and (-e "$outputdir/$outputfilename") ){
	#	print "skip: $outputfilename\n";
	#	goto skip_evt_single;
	#}
	&win2_single_evt($ymdhms,$net,$sta,$loc,$comp,$winformat1,$winformat2);
	skip_evt_single:
}

sub win2_single_evt {
    my ($ymdhms,$net,$sta,$loc,$comp,$win_i,$win_f)=@_;
    my ($year,$month,$day,$hour,$min,$sec)=&getWinformat($ymdhms);
	my $sec_int=sprintf("%02d",int($sec));
	my $msec = $sec-$sec_int ;
    my ($year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i)=&getWinformat($win_i);
    my ($year_f,$month_f,$day_f,$hour_f,$min_f,$sec_f)=&getWinformat($win_f);
	my $outputPath ="$tmpdir/$net.$sta.$loc.$comp.$year$month$day$hour$min$sec_int.zip";
    my $sec_i_int = int($sec_i);
    my $sec_f_int = int($sec_f);
    my $tmpsac = "$net.$sta.$loc.$comp.$year$month$day$hour$min$sec.sac";
	if ($outputfilename eq "0") {
            $outputfilename="$year$month$day$hour$min$sec_int.$net.$sta.$loc.$comp.sac";
    }
	my $t1 = "$year_i-$month_i-${day_i}T$hour_i:$min_i:$sec_i" ;
	my $t2 = "$year_f-$month_f-${day_f}T$hour_f:$min_f:$sec_f" ;

	#my $respname = "RESP.$net.$sta.$loc.$comp" ;
	my $respname = "$net.$sta.$loc.$comp.xml" ;	

	if ( ($skipresp eq "off") or (not -e "$outputdir_resp/$respname") ){
		&getresp($net,$sta,$loc,$comp,$t1,$t2,$outputdir_resp,$respname) ;
	}else{
		print "skip: $outputdir_resp/$respname\n";
	}

	if ( ($skip eq "on") and (-e "$outputdir/$outputfilename") ){
		print "skip: $outputdir/$outputfilename\n";
		goto skip_win2_single_evt ;
	}
	&getsac($net,$sta,$loc,$comp,$t1,$t2,$outputPath,$tmpdir,$tmpsac) ;
    &sacMerg("$tmpdir/$tmpsac",$year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i,$net,$sta,$loc,$comp,$outputdir,$outputfilename) ;
	#system(join(" ","rm -f $tmpsac"));
	system(join(" ","rm -f $tmpdir/$tmpsac $outputPath"));
	$outputfilename="0";
	skip_win2_single_evt:
}

sub evt_multi {
    my ($cmd)=@_;
    my ($ymdhms,$lat,$long,$depth,$mag,$mag_class,$phase1,$cut1,$phase2,$cut2,$net,$sta,$loc,$comp);
    if( ($ymdhms,$lat,$long,$depth,$mag,$mag_class,$phase1,$cut1,$phase2,$cut2,$net,$sta,$loc,$comp)=
    $cmd =~ m{($int/$int/$int,$int:$int:$re)\s+($re)\s+($re)\s+($re)\s+($re)\((\w+)\)\s+(\w+)\(($re)\)\s+(\w+)\(($re)\)\s+(.+)\s+(.+)\s+(.+)\s+(.+)}){

    }else{
        print STDERR "Invalid command of evt.\n";
		goto L_0003;
    }

    my ($year,$month,$day,$hour,$min,$sec)=&getWinformat($ymdhms);

	my ($phasename1,$trvt1)=&trvt($lat,$long,$depth,$phase1,$net,$sta);
	my ($phasename2,$trvt2);
	if ($phase1 ne $phase2){
		($phasename2,$trvt2)=&trvt($lat,$long,$depth,$phase2,$net,$sta);
	}else{
		($phasename2,$trvt2)=($phasename1,$trvt1);
	}
	
	my ($win1,$win2)=($trvt1+$cut1,$trvt2+$cut2);

	my $tmp = $omarker;
	$omarker = $win1*(-1);

	my ($year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i)=&Add_Delta_YMDHMS_MS($year,$month,$day,$hour,$min,$sec,0,0,0,0,0,$win1);
	my ($year_f,$month_f,$day_f,$hour_f,$min_f,$sec_f)=&Add_Delta_YMDHMS_MS($year,$month,$day,$hour,$min,$sec,0,0,0,0,0,$win2);

	my $winformat1 = &outputWinformat($year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i);
	my $winformat2 = &outputWinformat($year_f,$month_f,$day_f,$hour_f,$min_f,$sec_f);
	if ($phasename1 ne $phasename2){
		$phasename1_g=$phasename1;
		$phasename2_g=$phasename2;
		$trvt1_g=$trvt1-$win1;
		$trvt2_g=$trvt2-$win1;
	}else{
		$phasename1_g=$phasename1;
		$phasename2_g=-12345;
		$trvt1_g=$trvt1-$win1;
		$trvt2_g=-12345;
	}
	$evla_g = $lat;
	$evlo_g = $long;
	$evdp_g = $depth;
	$evmag_g = $mag;
	$evmagtyp_g = $mag_class;


	$net =~ s/_/?/g ;
	$net =~ s/%/*/g ;
	$net =~ s/ //g ;
	$sta =~ s/_/?/g ;
	$sta =~ s/%/*/g ;
	$sta =~ s/ //g ;
	$loc =~ s/_/?/g ;
	$loc =~ s/%/*/g ;
	$loc =~ s/ //g ;
	$comp =~ s/_/?/g ;
	$comp =~ s/%/*/g ;
	$comp =~ s/ //g ;

	my $t1 = "$year_i-$month_i-${day_i}T$hour_i:$min_i:$sec_i" ;
	my $t2 = "$year_f-$month_f-${day_f}T$hour_f:$min_f:$sec_f" ;

	my @nslcs = &getnslcs($net,$sta,$loc,$comp,$t1,$t2,$box) ;

	foreach my $nslc (@nslcs){
		my ($net_single,$sta_single,$loc_single,$comp_single) = split(",",$nslc) ;
		&evt_single($ymdhms,$net_single,$sta_single,$loc_single,$comp_single,$winformat1,$winformat2) ;
	}

	# initializing
	$phasename1_g=-12345;
    $phasename2_g=-12345;
    $trvt1_g=-12345;
    $trvt2_g=-12345;	
	$evla_g = -12345;
	$evlo_g = -12345;
	$evdp_g = -12345;
	$evmag_g = -12345;
	$evmagtyp_g = -12345;	
	$outputfilename=0;
	$omarker = $tmp;
	L_0003:
}


sub getnslcs {
	my ($net,$sta,$loc,$chn,$t1,$t2,$box)=@_ ;
	my @nslcs ;
	my $ua = LWP::UserAgent->new ;
	$ua->agent("MyApp/0.1") ;
	$ua->agent("X-Open-Api-Token/$token") ;
	#my $url = "http://service.iris.edu/irisws/fedcatalog/1/query" ;
	my $url = "https://quake.kigam.re.kr/fdsnws/availability/1/query" ;
	$url .= "?$box" ;
	$url .= "&net=$net&sta=$sta&cha=$chn&loc=$loc" ;
	$url .= "&starttime=$t1&endtime=$t2" ;

	#print "url(nslcs): $url\n" ;
	
	&check_rate() ;
	my $req = HTTP::Request->new(GET => $url) ;
	my $res = $ua->request($req) ;
	
	#print $res->is_success ;

	if ($res->is_success) {
		my $conts = $res->content ;
		my @conts = split("\n",$conts) ;
		foreach my $cont (@conts){
			chomp($cont) ;
			if (not ($cont=~m{=} or $cont!~m{\w} or $cont=~m{^\#}) ){
				my ($net,$sta,$loc,$chn,$t1,$t2) = split(" ",$cont) ;
				#print "$cont->($net,$sta,$loc,$chn,$t1,$t2)\n" ;
				push(@nslcs,"$net,$sta,$loc,$chn") ;
			}else{
				#print "$cont\n" ;
			}
		}
	}else{
		print $res->status_line, "\n";
	}
	return @nslcs ;
}


sub getsac {
	#no wildcard for this subroutine
	my ($net,$sta,$loc,$chn,$t1,$t2,$tmpzip,$outdir,$sacname)=@_ ;
	my $output = 0 ;
	#my $ua = LWP::UserAgent->new ;
	#$ua->agent("MyApp/0.1") ;
	#$ua->agent("X-Open-Api-Token/$token") ;
	my $ua = LWP::UserAgent->new(
		'User-Agent' => "stp/$version",
	) ;
	#my $url = "http://service.iris.edu/irisws/timeseries/1/query" ;
	my $url = "https://quake.kigam.re.kr/fdsnws/dataselect/1/query" ;
	$url .= "?net=$net&sta=$sta&loc=$loc&cha=$chn&starttime=$t1&endtime=$t2&format=sac.zip" ;
	
	#print "url: $url\n" ;

	&check_rate() ;
	my $req = HTTP::Request->new(GET => $url) ;
	$req->header('X-Open-Api-Token' => $token) ;

	my $res = $ua->request($req) ;
	
	#print $res->decoded_content ;
	#print "\n" ;

	if ($res->is_success) {
		make_path($outdir) if not -e $outdir ;
		open(my $f,">$tmpzip") or die "error writing file\n" ;
		binmode($f) ;
		print $f $res->content ;
		close($f) ;
		unzip $tmpzip => "$outdir/$sacname" ;	
		$output = 1 ;
	}else{
		print $res->status_line, "\n";
	}
	return $output ;

}

sub getresp {
	my ($net,$sta,$loc,$chn,$t1,$t2,$outdir,$respname)=@_ ;
	#http://service.iris.edu/irisws/resp/1/query?net=7D&sta=G30A&loc=--&cha=BHZ&start=2012-01-01T05:24:35.80&end=2012-01-01T05:57:55.80
	my $output = 0 ;
	my $ua = LWP::UserAgent->new(
		'User-Agent' => "stp/$version",
	) ;
	make_path($outdir) if not -e $outdir ;

	my $outputpath = "$outdir/$respname" ;

	&warning_file_exist($outputpath) ;

	#my $urlresp = "http://service.iris.edu/irisws/resp/1/query" ;
	my $urlresp = "https://quake.kigam.re.kr/fdsnws/station/1/query" ;
	#$urlresp .= "?net=$net&sta=$sta&loc=$loc&cha=$chn&start=$t1&end=$t2" ;	
	$urlresp .= "?net=$net&sta=$sta&loc=$loc&cha=$chn&start=$t1&end=$t2&format=xml&level=response" ;	
	#$urlresp .= "?net=$net&sta=$sta&loc=$loc&cha=$chn&start=$t1&end=$t2&format=text" ;	
	#$urlresp .= "?net=$net&sta=$sta&loc=$loc&cha=$chn&start=$t1&end=$t2&format=geocsv" ;	

	&check_rate() ;
	my $req = HTTP::Request->new(GET => $urlresp) ;
	$req->header('X-Open-Api-Token' => $token) ;
	
	my $res = $ua->request($req) ;
	
	if ($res->is_success) {
		make_path($outdir) if not -e $outdir ;
		open(my $f,">$outputpath") or die "error writing file  ($outputpath)\n" ;
		binmode($f) ;
		print $f $res->content ;
		close($f) ;
		print "saved: $outputpath\n" if $verbose > 0;
		$output = 1 ;
	}else{
		#print $res->status_line, "\n";
	}
	return $output ;
}

sub waiting {
	my $term = Term::ReadLine->new("stp");
	$term->ornaments(0);
	while ( defined ($_ = $term->readline($prompt)) ) {
		chomp;
		&splitResp($_);
		$term->addhistory($_) if /\S/;			
	}
}

sub initialMsg {
	print STDERR "
+++++++++++++++++++++++++++++
|        stp-kigam.pl       |
|(https://quake.kigam.re.kr)|
+++++++++++++++++++++++++++++

Version $version (Sep. 2022)

Type help(h) to see usage.

---------------------------
\n"
}

sub splitResp {
	my ($input)=@_;
	if(my ($linuxCmd) = $input =~ m{^\s*!(.*)}){
		system(join(" ","$linuxCmd"));
	}elsif($input =~ m{^quit|(:?^q)}i){
		die "\n";
	}elsif($input =~ m{^help|(:?^h)}i){
		&help();
	}elsif(my ($wincommand) = $input =~ m{^\s*win\s+(.*)$}i){
		&generalWin($wincommand);
	}elsif(my ($inputpath) = $input =~ m{^\s*input\s+(.*)$}i){
		&input($inputpath);
	}elsif($input =~ m{^sta}i){
		&stainfo();
	}elsif(my ($omarker_input) = $input =~ m{^seto\s+($re)}i ){
		print "omarker from [$omarker] to ";
		$omarker=$omarker_input;
		print "[$omarker]\n";
	}elsif( my ($OUTPUTDIR) = $input =~ m{^dir\s+(.+)}i){
		print "directory from [$outputdir] to ";
		$outputdir = $OUTPUTDIR;
		print "[$outputdir]\n";
	}elsif( my ($OUTPUTDIR_RESP) = $input =~ m{^dirresp\s+(.+)}i){
		print "resp's directory from [$outputdir_resp] to ";
		$outputdir_resp = $OUTPUTDIR_RESP ;
		print "[$outputdir_resp]\n";
	}elsif( my ($evt_cmd) = $input =~ m{^evt\s+(.+)}i){
		&evt_multi($evt_cmd);
	}elsif( my ($factors) = $input =~ m{^dec\s+(.+)}i){
		print "decimation from [$decimation] to ";
		if ($factors =~m{off}i) {
			$decimation = "off";
		}else{
			$decimation = "on";
			@factors = &dec($factors);
		}
		print "[$decimation] with factor";
		print " $_" foreach @factors;
		print "\n";
	}elsif( my ($onoff) = $input =~ m{^skip\s+(.+)}i){
		if ($onoff eq "on"){
			print "changed the skip from [$skip] to ";
			$skip = $onoff;
			print "[$skip] \n";
		}elsif($onoff eq "off"){
			print "changed the skip from [$skip] to ";
			$skip = $onoff;
			print "[$skip] \n";
		}else{
			print "Wrong skip command.";
		}
	}else{
		print "Wrong command: $input\n";
	}
}

sub mkTmpDir{
	#my $username = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
	&cleaningTmpdir();
	if (not -e "$tmpdir"){
		&resp_mkTmpDir();
	}
	#&cleaningTmpdir();
	mkdir "$tmpdir/SAC" if not -e "$tmpdir/SAC";
	#&cleaningSACdir();
}

sub cleaningTmpdir {
    #if(not &is_folder_empty("$tmpdir")){
    if(-e $tmpdir){
        #system(join(" ","rm -rf $tmpdir/*"));
        system(join(" ","rm -rf $tmpdir"));
		&File::Path::make_path($tmpdir) ;
    }
}

#sub cleaningSACdir {
#	if(not &is_folder_empty("$tmpdir/SAC")){
#		system(join(" ","rm -f $tmpdir/SAC/*"));
#	}
#}

sub help {
	print STDERR "
usage:
 1. win NET STA COMP yyyy/mm/dd,hh:mm:ss.ms span(unit)
    NET:
      network code or % for all networks
    STA:
      station code or % for all stations
    COMP:
      component such as BHZ or % for all components.
    span a length of window you want to cut and its unit
	unit can be any one of Y(year), M(month), D(day)
      , h(hour), m(min), s(sec).
    e.g., 
      win % % BHZ 2010/01/01,00:00:00 1h
      win KS GAHB BH_ 2010/01/01,00:00:00 1h
      (% and _ are wild cards that are similar with * and ? in Linux)
 2. win NET STA COMP yyyy/mm/dd,hh:mm:ss.ms yyyy/mm/dd,hh:mm:ss.ms 
   	e.g.,
      win KS GAHB BHZ 2010/01/01,00:00:00 2010/01/01,01:00:00

 3. !(linux command)
    For example, 
      !ls

 4. dir output_directory ($outputdir)
    You can change the directory where the output sac files are saved.
    The directory will be automatically made.

 5. input filepath
    The file contains the commands of the stp.

 6. sta
    station information.

 7. seto time_o (in sec)
    The O marker is set to yyyy/mm/dd,hh:mm:ss.ms + time_o
	default=$omarker
    Maybe it works, but I have not tested this command.

 8. evt origin_time lat long depth mag(class) P|S|O(+t1) P|S|O(+t2) net sta chn
    e.g.,
      evt 2010/01/01,12:34:56.5 30 120 123.5 5.6(mb) P(-100) S(200) KS % BHZ
      evt 2010/01/10,00:27:41.85 40.6654 -124.4669 20.6 6.5(MW) P(-50) P(200) K_ % BHZ
      evt 2013/04/20,00:02:47.0 30.31 102.89 14 6.6(MW) P(-100) P(100) K_ % BH_
      evt 2013/04/20,00:02:47.0 30.31 102.89 14 6.6(MW) O(-200) O(500) K_ % BH_
      evt 2016/09/12,10:44:32.0 35.77 129.19 10 5.8(M) O(-200) O(500) KS % HHZ
      evt 2017/11/15,05:29:32.0 36.12 129.36 9 5.4(Mw) O(-200) S(500) KS % HGZ

      'O' denotes origin time. It is useful when you do not want to waste time in ray-tracing (taup).
      If wanting to use other phase, such as PP, you should modify a subroutine 'trvt' below.

 9. dec factor1 [factor2...]     
     downsampling sacfiles by decimate command of the SAC(v101.6a)
     where the factors should be between 2 and 6.
     e.g.,
       dec 2 5     (for downsampling from 100 Hz to 10 Hz)
       dec 2 5 2 5 (for downsampling from 100 Hz to 1 Hz)

 10. skip on|off (off is default)
     If the output file exists at an path for sac file to be saved,
     `stp' is skipped. It works only with `evt'.

 11. quit(q)

 12. dirresp name ($outputdir_resp)
     where response files are saved.

";
}

sub Add_Delta_YMDHMS_MS {
    my ($year,$month,$date,$hour,$min,$sec,
        $Dyear,$Dmonth,$Ddate,$Dhour,$Dmin,$Dsec)=@_;
    my $output; my @output;
    my $secint = int($sec); 
	my $secdec = $sec-$secint;
    my $Dsecint = int($Dsec); 
	my $Dsecdec = $Dsec-$Dsecint;
	$Dsecint += $secint;
    #print "($year,$month,$date,$hour,$min,$secint,$Dyear,$Dmonth,$Ddate,$Dhour,$Dmin,$Dsecint)\n";
    #@output = &Date::Calc::XS::Add_N_Delta_YMDHMS($year,$month,$date,$hour,$min,$secint,$Dyear,$Dmonth,$Ddate,$Dhour,$Dmin,$Dsecint);
    @output = &Date::Calc::XS::Add_N_Delta_YMDHMS($year,$month,$date,$hour,$min,0,$Dyear,$Dmonth,$Ddate,$Dhour,$Dmin,$Dsecint);
    my $subsecond = $secdec+$Dsecdec; my $subsecondINT = int($subsecond); my $subsecondDEC = $subsecond-$subsecondINT;
    @output = &Date::Calc::XS::Add_N_Delta_YMDHMS(@output,0,0,0,0,0,$subsecondINT);
    $output[5] += $subsecondDEC;
	$output[0] = sprintf("%04d",$output[0]) ; #y
	$output[1] = sprintf("%02d",$output[1]) ; #m
	$output[2] = sprintf("%02d",$output[2]) ; #d
	$output[3] = sprintf("%02d",$output[3]) ; #h
	$output[4] = sprintf("%02d",$output[4]) ; #m
	$output[5] = sprintf("%05.2f",$output[5]) ; #s
    return @output;
}

sub span2win_f {
	my ($year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i,$span,$unit)=@_;
	my ($year_f,$month_f,$day_f,$hour_f,$min_f,$sec_f)=@_;
	my $output;
	if ($unit =~ m{Y}){
		($year_f,$month_f,$day_f,$hour_f,$min_f,$sec_f)=&Add_Delta_YMDHMS_MS($year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i,$span,0,0,0,0,0)
	}elsif($unit =~ m{M}){
		($year_f,$month_f,$day_f,$hour_f,$min_f,$sec_f)=&Add_Delta_YMDHMS_MS($year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i,0,$span,0,0,0,0)
	}elsif($unit =~ m{D}){
		#print STDERR "Add_Delta_YMDHMS_MS($year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i,0,0,$span,0,0,0)\n";
		($year_f,$month_f,$day_f,$hour_f,$min_f,$sec_f)=&Add_Delta_YMDHMS_MS($year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i,0,0,$span,0,0,0)
	}elsif($unit =~ m{h}){
		($year_f,$month_f,$day_f,$hour_f,$min_f,$sec_f)=&Add_Delta_YMDHMS_MS($year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i,0,0,0,$span,0,0)
	}elsif($unit =~ m{m}){
		($year_f,$month_f,$day_f,$hour_f,$min_f,$sec_f)=&Add_Delta_YMDHMS_MS($year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i,0,0,0,0,$span,0)
	}elsif($unit =~ m{s}){
		($year_f,$month_f,$day_f,$hour_f,$min_f,$sec_f)=&Add_Delta_YMDHMS_MS($year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i,0,0,0,0,0,$span)
	}else{
		print "Error in unit, which should be one of the Y, M, D, h, m, and s.\n";
	}
	#($year_f,$month_f,$day_f,$hour_f,$min_f,$sec_f)=&Add_Delta_YMDHMS_MS($year_f,$month_f,$day_f,$hour_f,$min_f,$sec_f,0,0,1,0,0,0);
	return ($year_f,$month_f,$day_f,$hour_f,$min_f,$sec_f);
}

sub input {
	my ($file)=@_;
	open(FID,"<$file") or die "Error when read $file.";
	my @file = <FID>;
	close(FID);
	foreach my $line (@file){ chomp($line);
		#print "$line\n";
		&splitResp($line);
	}
}

sub getWinformat {
	my ($input)=@_;
	my $output;
	my ($year,$month,$day,$hour,$min,$sec)=$input=~m{(\d{4})/(\d{1,2})/(\d{1,2}),(\d{1,2}):(\d{1,2}):($re)};
	return ($year,$month,$day,$hour,$min,$sec);
}

sub trvt {
	my ($lat,$long,$depth,$PHASE,$net,$sta)=@_;
	my ($trvt,$phasename)=("-12345","-12345");
	if  (not $PHASE =~ m{[O]}){
    	#print "Error: PHASE($PHASE) should be P,S, and O(origin time).";
    	print "Error: PHASE($PHASE) should O(origin time).";
        goto L_0004;
	}elsif($PHASE =~ m{O}){
		($phasename,$trvt) = ("O",0) ;
	}
	L_0004:
	#print STDERR "(\$phasename,\$trvt)=($phasename,$trvt)\n";
	return ($phasename,$trvt);	
}

sub getscalar {
	my ($fname,$key)=@_ ;
	my $output ;
	open(F,"<$fname") or die "error: not exist ($fname)\n" ;
	while(my $l=<F>){
		chomp($l) ;
		if ($l=~m[^\s*\#]){
			# nothing to do
		}elsif($l=~m[^\s*$key\s*=\s*(.+)\s*$]){
			($output) = $1 ;
			last ;
		}else{
			#nothing to do
		}
	}
	if (not defined $output){
			print STDERR "warning: no ($key) in ($fname)\n" ;
	}
	return $output ;
}

sub resp_mkTmpDir {
	print "$tmpdir will be generated. [y/n]: ";
	my $ans=<>; chomp($ans);
	if ($ans =~ m{y}i){
		mkdir "$tmpdir";
		if (not -e "$tmpdir/SAC" or not -e $tmpdir){
			&File::Path::make_path("$tmpdir/SAC") ;
		}
	}elsif($ans =~ m{n}i){
		die "\n";
	}else{
		&resp_mkTmpDir();
	}
}

#sub is_folder_empty {
#    my ($dirname) = @_;
#    opendir(my $dh, $dirname) or die "Not a directory";
#    return scalar(grep { $_ ne "." && $_ ne ".." } readdir($dh)) == 0;
#}

sub outputWinformat {
	my ($year,$month,$day,$hour,$min,$sec)=@_;
    $year = &NumberFormat($year,"4.0");
    $month = &NumberFormat($month,"2.0");
    $day = &NumberFormat($day,"2.0");
    $hour = &NumberFormat($hour,"2.0");
    $min = &NumberFormat($min,"2.0");
    $sec = &NumberFormat($sec,"2.2");
	my $output = "$year/$month/$day,$hour:$min:$sec";
	return $output;
}

sub NumberFormat  {
    my $output = undef;
    my ($input,$format)=@_;
    $format = "$format";
    my $RegexpFormat = '(\w*)\.?(\w*)';
    print STDERR "Error* format: $format\n" if $format !~ /$RegexpFormat/;
    my ($formatIntegerLength,$formatDecimalLength) = $format =~ /$RegexpFormat/;
    my ($inputInteger,$inputDecimal) = $input =~ /$RegexpFormat/;
    my ($inputIntegerLength,$inputDecimalLength) = (length($inputInteger),length($inputDecimal));
    #print STDERR "Error: inputIntegerLength($inputIntegerLength) > formatIntegerLength($formatIntegerLength)\n" if $inputIntegerLength > $formatIntegerLength;
    #print STDERR "Error: inputDecimalLength($inputDecimalLength) > formatDecimalLength($formatDecimalLength)\n" if $inputDecimalLength > $formatDecimalLength;
    my $attachInteger = $formatIntegerLength-$inputIntegerLength;
    my $attachDecimal = $formatDecimalLength-$inputDecimalLength;
    if ($attachInteger > 0){$inputInteger = "0". $inputInteger foreach(1..$attachInteger)};
    if ($attachDecimal > 0){$inputDecimal = $inputDecimal . "0" foreach(1..$attachDecimal)};
    if (not $formatDecimalLength >= 1){
        $output = $inputInteger;
    }else{
        $output = "$inputInteger.$inputDecimal";
    }
    return "$output";
}

sub sacMerg {
	my ($input,$year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i,$net,$sta,$loc,$comp,$outputdir,$outputfilename)=@_;
	#my ($input,$year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i,$net,$sta,$comp)=@_;
	$year_i = &NumberFormat($year_i,"4.0");
	$month_i = &NumberFormat($month_i,"2.0");
	$day_i = &NumberFormat($day_i,"2.0");
	$hour_i = &NumberFormat($hour_i,"2.0");
	$min_i = &NumberFormat($min_i,"2.0");
	$sec_i = &NumberFormat($sec_i,"2.2");
	my ($sec,$ms)=$sec_i=~m{($re)\.($re)};
	if (not -e $outputdir){
		&File::Path::make_path($outputdir);
	}
	#my ($slat,$slong,$sele)=&sta_laloel($net,$sta);
	($year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i)=&Add_Delta_YMDHMS_MS
		($year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i,
		0,0,0,0,0,$omarker);
	my $jday=&Date::Calc::XS::Day_of_Year($year_i,$month_i,$day_i);
	my ($sec_sac,$msec_sac)=&sec2sac_s_ms($sec_i);
	&warning_file_exist("$outputdir/$outputfilename") ;
	open(SAC,"|$sac >> $logfile 2>&1") or die "Error open sac.";
	print SAC "r $input\n";
	#print SAC "merge gap zero overlap average \n";
	#print SAC "merge gap interp overlap average \n";
	#print SAC "chnhdr stla $slat stlo $slong stel $sele\n";
	print SAC "chnhdr o gmt $year_i $jday $hour_i $min_i $sec_sac $msec_sac\n";
	if ($comp =~ m{Z$}){
		print SAC "chnhdr cmpaz -12345\n";
		print SAC "chnhdr cmpinc 0\n";
	}elsif($comp =~ m{[N]$}){
		print SAC "chnhdr cmpaz 0\n";
		print SAC "chnhdr cmpinc 90\n";
	}elsif($comp =~ m{[E]$}){
		print SAC "chnhdr cmpaz 90\n";
		print SAC "chnhdr cmpinc 90\n";
	}
	
	if ($decimation eq "on") {
		foreach my $factor (@factors){
			print SAC "decimate $factor\n";
		}
	}
	#print SAC "chnhdr t1 $trvt1_g\n";
	#print SAC "chnhdr t2 $trvt2_g\n";
	#print SAC "chnhdr kt1 $phasename1_g\n";
	#print SAC "chnhdr kt2 $phasename2_g\n";
	print SAC "chnhdr evla $evla_g\n";
	print SAC "chnhdr evlo $evlo_g\n";
	print SAC "chnhdr evdp $evdp_g\n";
	print SAC "chnhdr mag $evmag_g\n";
	print SAC "chnhdr imagtyp $evmagtyp_g\n";
	print SAC "\n";
	print SAC "\n";
	print SAC "\n";
	print SAC "chnhdr allt (0 - &1,o) IZTYPE IO\n"; # v3.07
	#print SAC "w $output\n";
	print "saved: $outputdir/$outputfilename\n" if $verbose > 0;
	print SAC "w $outputdir/$outputfilename\n";
	print SAC "q\n";
	close(SAC);
}

sub sec2sac_s_ms {
	my ($float)=@_;
	my $sec=int($float);
	my $msec=int(($float-$sec)*1000+0.5);
	
	return ($sec,$msec);
}

sub generalWin {
	my ($input)=@_;
	my ($net,$sta,$loc,$comp,$win_i,$win_f,$span,$unit);
	#my ($net,$sta,$comp,$win_i,$win_f,$span,$unit);
	if (($net,$sta,$loc,$comp,$win_i,$span,$unit) = $input =~ m{(.+)\s+(.+)\s+(.+)\s+(.+)\s+(.+)\s+($re)([YMDhms])}){
		&win1_multi($net,$sta,$loc,$comp,$win_i,$span,$unit);
	}elsif(($net,$sta,$loc,$comp,$win_i,$win_f) = $input =~ m{(.+)\s+(.+)\s+(.+)\s+(.+)\s+(.+)\s+(.+)}){
		&win2_multi($net,$sta,$loc,$comp,$win_i,$win_f);
	}else{
		print "Error: wrong win command.\n";
	}
}

sub win1_multi {
	my ($net,$sta,$loc,$comp,$win_i,$span,$unit)=@_;

	my ($year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i)=&getWinformat($win_i);
	my ($year_f,$month_f,$day_f,$hour_f,$min_f,$sec_f)=&span2win_f($year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i,$span,$unit);

	my $t1 = "$year_i-$month_i-${day_i}T$hour_i:$min_i:$sec_i" ;
	my $t2 = "$year_f-$month_f-${day_f}T$hour_f:$min_f:$sec_f" ;

	$net =~ s/_/?/g ;
	$net =~ s/%/*/g ;
	$net =~ s/ //g ;
	$sta =~ s/_/?/g ;
	$sta =~ s/%/*/g ;
	$sta =~ s/ //g ;
	$loc =~ s/_/?/g ;
	$loc =~ s/%/*/g ;
	$loc =~ s/ //g ;
	$comp =~ s/_/?/g ;
	$comp =~ s/%/*/g ;
	$comp =~ s/ //g ;

	my @nslcs = &getnslcs($net,$sta,$loc,$comp,$t1,$t2,$box) ;

	foreach my $nslc (@nslcs){
		my ($net_single,$sta_single,$loc_single,$comp_single) = split(",",$nslc) ;
			&win1_single($net_single,$sta_single,$loc_single,$comp_single,$win_i,$span,$unit) ;
	}

}

sub win1_single {
	my ($net,$sta,$loc,$comp,$win_i,$span,$unit)=@_;

    my ($year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i)=&getWinformat($win_i);
	my ($year_f,$month_f,$day_f,$hour_f,$min_f,$sec_f)=&span2win_f($year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i,$span,$unit);
	my $outputPath ="$tmpdir/$net.$sta.$comp.$year_i$month_i$day_i$hour_i$min_i$sec_i.zip";
    my $sec_i_int = int($sec_i);
    my $sec_f_int = int($sec_f);
    my $tmpsac = "$net.$sta.$loc.$comp.$year_i$month_i$day_i$hour_i$min_i$sec_i_int.sac";
	if ($outputfilename eq "0") {
            $outputfilename="$year_i$month_i$day_i$hour_i$min_i$sec_i_int.$net.$sta.$loc.$comp.sac";
    }
	my $t1 = "$year_i-$month_i-${day_i}T$hour_i:$min_i:$sec_i" ;
	my $t2 = "$year_f-$month_f-${day_f}T$hour_f:$min_f:$sec_f" ;
	#my $respname = "RESP.$net.$sta.$loc.$comp" ;
	my $respname = "$net.$sta.$loc.$comp.xml" ;
	&getresp($net,$sta,$loc,$comp,$t1,$t2,$outputdir_resp,$respname) ;
	&getsac($net,$sta,$loc,$comp,$t1,$t2,$outputPath,$tmpdir,$tmpsac) ;
    &sacMerg("$tmpdir/$tmpsac",$year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i,$net,$sta,$loc,$comp,$outputdir,$outputfilename) ;
	#system(join(" ","rm -f $tmpsac"));
	system(join(" ","rm -f $tmpdir/$tmpsac $outputPath"));
	$outputfilename="0";
	skip_win1_single:
}

sub win2_multi {
    my ($net,$sta,$loc,$comp,$win_i,$win_f)=@_;

	my ($year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i)=&getWinformat($win_i);
	my ($year_f,$month_f,$day_f,$hour_f,$min_f,$sec_f)=&getWinformat($win_i);

	my $t1 = "$year_i-$month_i-${day_i}T$hour_i:$min_i:$sec_i" ;
	my $t2 = "$year_f-$month_f-${day_f}T$hour_f:$min_f:$sec_f" ;

	$net =~ s/_/?/g ;
	$net =~ s/%/*/g ;
	$net =~ s/ //g ;
	$sta =~ s/_/?/g ;
	$sta =~ s/%/*/g ;
	$sta =~ s/ //g ;
	$loc =~ s/_/?/g ;
	$loc =~ s/%/*/g ;
	$loc =~ s/ //g ;
	$comp =~ s/_/?/g ;
	$comp =~ s/%/*/g ;
	$comp =~ s/ //g ;

	my @nslcs = &getnslcs($net,$sta,$loc,$comp,$t1,$t2,$box) ;

	foreach my $nslc (@nslcs){
		my ($net_single,$sta_single,$loc_single,$comp_single) = split(",",$nslc) ;
		&win2_single($net_single,$sta_single,$loc_single,$comp_single,$win_i,$win_f) ;
	}

}

sub win2_single {
	my ($net,$sta,$loc,$comp,$win_i,$win_f)=@_;
	my ($year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i)=&getWinformat($win_i);
	my ($year_f,$month_f,$day_f,$hour_f,$min_f,$sec_f)=&getWinformat($win_f);
	my $outputPath ="$tmpdir/$net.$sta.$comp.$year_i$month_i$day_i$hour_i$min_i$sec_i.zip";
    my $sec_i_int = int($sec_i);
    my $sec_f_int = int($sec_f);
    my $tmpsac = "$net.$sta.$loc.$comp.$year_i$month_i$day_i$hour_i$min_i$sec_i_int.sac";
	if ($outputfilename eq "0") {
            $outputfilename="$year_i$month_i$day_i$hour_i$min_i$sec_i_int.$net.$sta.$loc.$comp.sac";
    }
	my $t1 = "$year_i-$month_i-${day_i}T$hour_i:$min_i:$sec_i" ;
	my $t2 = "$year_f-$month_f-${day_f}T$hour_f:$min_f:$sec_f" ;
	#my $respname = "RESP.$net.$sta.$loc.$comp" ;
	my $respname = "$net.$sta.$loc.$comp.xml" ;
	&getresp($net,$sta,$loc,$comp,$t1,$t2,$outputdir_resp,$respname) ;
	&getsac($net,$sta,$loc,$comp,$t1,$t2,$outputPath,$tmpdir,$tmpsac) ;
    &sacMerg("$tmpdir/$tmpsac",$year_i,$month_i,$day_i,$hour_i,$min_i,$sec_i,$net,$sta,$loc,$comp,$outputdir,$outputfilename) ;
	#system(join(" ","rm -f $tmpsac"));
	system(join(" ","rm -f $tmpdir/$tmpsac $outputPath"));
	$outputfilename="0";
	skip_win2_single:
}


sub check_rate {
	my $tok = tv_interval ($t0, [gettimeofday]) ;
	#if ($#times < 9){
	if ($#times < $number_averaged-1){
		push(@times,$tok) ;
		goto skip_check_rate ;
	}else{
		shift(@times) ;
		push(@times,$tok) ;
	}
	my $rate = &avgrate() ;
	&shiftzero() ;
	#print "2 $#times @times\n" ;
	#printf("rate = %.2f connection/s\n",$rate) ;
	#$rate should be less than 10.0
	#if ($rate > 5.0){
	if ($rate > $rate_threshold){
		#5.0 number/s
		#usleep(1e6*0.5) ;
		usleep($sleeping_time) ;
		#print "sleep\n" ;
		printf("sleep 0.5, rate = %.2f connection/s\n",$rate) if $verbose == 1 ;
	}
	skip_check_rate:
}

sub avgrate {
	my $s = 0 ;
	my $avg = 0 ;
	$avg = $number_averaged/($times[$number_averaged-1]-$times[0]) ;
	return $avg ;
}

sub shiftzero {
	my $tok = tv_interval ($t0, [gettimeofday]) ;
	for (my $i=0; $i<=$#times; $i++){
		$times[$i] = $times[$i] - $tok ;
	}
	$t0 = [gettimeofday] ;
}

sub warning_file_exist {
	my ($fname)=@_ ;
	if (-e $fname){
		print "warning: file will be overwritten ($fname)\n" ;
	}
}

sub read_token {
	my ()=@_ ;
	my $dir = "$ENV{HOME}/.stp-kigam" ;
	my $fname = "$dir/token" ;
	my $token = "" ;
	if (-e $fname){
		open(my $f,"<$fname") ;
		my @output = <$f> ;
		close($f) ;
		$token = join('',@output) ;
		chomp($token) ;
	}else{
		`mkdir -p $dir` ;
		print "not found token file ($fname)\n" ;
		print " \$) echo \"your token\" > $fname\n" ;
		print " \$) chmod 600 $fname\n" ;
		exit ;
	}
	return $token ;
}
