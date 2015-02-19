#!/usr/bin/perl
# $Id: gi_fetch.ncgr.sql.pl,v 1.5 2004/11/03 00:54:44 givans Exp $
#
#
# Fetches GI list from NCBI
use Getopt::Std;
use LWP::UserAgent;
use lib '/home/cgrb/cgrb/givans/lib';
use NCGRDB;

my $ua = LWP::UserAgent->new(timeout	=>	15);
$ua->agent("Netsacape/6.0 ");

my $ncgr = NCGRDB->new();

getopts('fq');

open(LOG,">gi_fetch.ncgr.log") or die "can't open log file: $!";



my $mol = 'nucleotide';

my $genus_list = $ncgr->genus_list();

#foreach (@$genus_list) {
#    print $_->[0], "\n";
#}


foreach (@$genus_list) {
    my $term = $_->[0];
    my $term_base = $term;

    print STDOUT "\n\nFetching all '$mol' sequences from '$term'\n" unless ($opt_q);
    print LOG "Fetching all '$mol' sequences from '$term'\n" unless ($opt_q);

    my $file = "$term" . ".gi.lst";

    my $db = $mol;
    my $http = "http://www.ncbi.nlm.nih.gov/entrez/eutils";

    open(GI,">$file") || die "can't open '$file': $!" if ($file);

    $term .= "[ORGN] NOT microsatellite NOT microstatellite NOT ribosomal NOT chloroplast";

    my $esearch_count = "$http/esearch.fcgi?db=$db&term=";

    my ($esearch_count_result) = (0);
    my $esearch_count_result = NCBI_RQST($ua,"$esearch_count$term",$term_base);

    my $count = "";
    if ($esearch_count_result =~ /\<Count\>(\d+)\<\/Count\>/) {
	$count = $1;
	print "'$1' GI's for '$term_base'\n";
    } else {
	print STDOUT "can't extract count from result file\n" unless ($opt_q);
	print LOG "can't extract count from result file\n" unless ($opt_q);
    }

#   The following if{} statement will skip printing GI numbers if no new ones exist

    if ($count == $ncgr->genus_gi_cnt($term_base)) {
	print "no new gi's for '$term_base'\n";
	next unless ($opt_f);
    }

#####

    print STDOUT "Fetching $count GI's\n" unless ($opt_q);
    print LOG "Fetching $count GI's\n" unless ($opt_q);

    my $esearch2 = "$http/esearch.fcgi?db=$db&retmax=$count&term=";

    my $esearch_result = NCBI_RQST($ua,"$esearch2$term",$term_base);

    my @esearch = split /\n/, $esearch_result;

    my $total = 0;
    foreach $line (@esearch) {

	if ($line =~ /\<Id\>(\d+)\<\/Id\>/) {
	    ++$total;
	    print { $file ? "GI" : "STDOUT" } "$1\n";
	    if ($ncgr->gi_chk($1)) {
		print "'$1' exists for '$term_base'\n";
	    } else {
		print "'$1' doesn't exist for '$term_base'\n";
		print "adding '$1' to list\n";
		if(!$ncgr->gi_add($1,$term_base)) {
		    die "can't add '$1' to database: $!";
		}
	    }

	} else {
	    next;
	}
    }


    close(GI) if ($file);

    print STDOUT "$total gi's added to $file\n" unless ($opt_q);
    print LOG "$total gi's added to $file\n" unless ($opt_q);

#    exit;

}

sub NCBI_RQST {
    my $ua = shift;
    my $url = shift;
    my $term_base = shift;

    my $request = 0;
  NCBI_REQUEST: while ($request == 0) {

#	Create a request object
    my $req = HTTP::Request->new(POST	=>	$url);
    $req->content_type('application/x-www-form-urlencoded');

#	Pass request object to the user agent and get a response
    my $res = $ua->request($req);

#	Check the outcome of the response
    if ($res->is_success) {
	$request = 1;
	return $res->content;
    } else {
	print "HTTP request failed for '$term_base' -- Trying again\n";
    }

}
}
