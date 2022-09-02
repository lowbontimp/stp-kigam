#!/usr/bin/env perl

use strict ;
use warnings ;
use XML::LibXML qw () ;
use XML::LibXML::XPathContext qw () ;

#my $xmlfname = "events.1A.xml" ;
#my $xmlfname = 'events.YP.xml' ;

my $xmlfname = $ARGV[0] ;

my $ns = `perl -lane 'if (m{xmlns=\"(.+?)\"}){print \$1; last;}' $xmlfname` ;
chomp($ns) ;

my $parser = XML::LibXML->new() ;
my $doc = $parser->parse_file($xmlfname) ;
my $root = $doc->getDocumentElement ;

my $xpc = XML::LibXML::XPathContext->new($doc) ;
$xpc->registerNs(y => "$ns") ;

#/quakeml/eventParameters/event/origin/time
#/quakeml/eventParameters/event/origin/latitude
#/quakeml/eventParameters/event/origin/longitude
#/quakeml/eventParameters/event/origin/depth
#/quakeml/eventParameters/event/magnitude/mag/value
#/quakeml/eventParameters/event/magnitude/type/
#<event publicID="smi:ISC/evid=10379476">

#my $path = &mkpath("quakeml","eventParameters","event") ;

#print "$path\n" ;

foreach my $atrid ($xpc->findnodes('/y:quakeml/y:eventParameters/y:event')){
	my $evtid = $xpc->findvalue( '@publicID' , $atrid) ;
	($evtid) = $evtid =~ m{smi:ISC/evid=(\d+)} ;
	my $time = $xpc->findvalue( 'y:origin/y:time/y:value' , $atrid) ;
	my $lat = $xpc->findvalue( 'y:origin/y:latitude/y:value' , $atrid) ;
	#my $lat = &findvalues($xpc,$atrid,"y:origin/y:latitude"," ") ;
	my $lon = $xpc->findvalue( 'y:origin/y:longitude/y:value' , $atrid) ;
	my $dep = $xpc->findvalue( 'y:origin/y:depth/y:value' , $atrid) ;
	#my $mag = $xpc->findvalue( 'y:magnitude/y:mag/y:value' , $atrid) ;
	#my $magtype = $xpc->findvalue( 'y:magnitude/y:type' , $atrid) ;
	#print "$mag\n" ;
	#print "$magtype\n" ;
	#my $mag = join " ", map {
	#	$_->to_literal();
	#} $xpc->findnodes('y:magnitude/y:mag/y:value' , $atrid) ;
	my $mags = &findvalues($xpc,$atrid,"y:magnitude/y:mag/y:value"," ") ;
	my $magtypes = &findvalues($xpc,$atrid,"y:magnitude/y:type"," ") ;
	my @mags = split(" ",$mags) ;
	my @magtypes = split(" ",$magtypes) ;
	#print "$lat\n" ;
	#print "$mag\n" ;
	#chomp( ($time,$lat,$lon,$dep,@mags,$magtypes) ) ;
	$dep *= 0.001 ;
	print "$evtid $time $lat $lon $dep" ;
	for (my $i=0; $i<=$#mags; $i++){
		print " $mags[$i]($magtypes[$i])" ;
	}
	print "\n" ;
}

sub findvalues {
	my ($xpc,$atrid,$xpath,$spliter)=@_ ;
	my $output = join "$spliter", map {
		$_->to_literal();
	} $xpc->findnodes($xpath , $atrid) ;
	return $output ;
}
