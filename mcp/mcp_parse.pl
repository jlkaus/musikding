#!/usr/bin/perl

use strict;
use warnings;
use XML::DOM;
use HTML::Tree;
use HTML::TreeBuilder;
use YAML::Any;
use LWP::UserAgent;
use POSIX;

our $pdata_url = "http://minnesota.publicradio.org/radio/services/cms/pieces_played/";
our $ydir = "/home/jlkaus/www.sessrumnir.net/mcpdata/";

my $ua = LWP::UserAgent->new;
$ua->agent("MyApp/0.1 ");

my $lastsize = -1;
my $lastdate = "00000000";

my $first = 1;

while(1) {
	if(!$first) {
		print "Sleeping\n";
		sleep 61;
	}
	$first = undef;

	my $curname = POSIX::strftime "%Y%m%d", localtime(time() + 2*60*60);
	print "Working on $curname at ".(scalar localtime(time()+2*60*60))."\n";

	print "Fetching $pdata_url\n";
	my $req = HTTP::Request->new(GET => $pdata_url);
	my $res = $ua->request($req);
	if (!$res->is_success) {
		print "Request failed: [$res->status_lin]\n";
		next;
  	}
	print "Playlist HTML retrieved\n";

	my $doc = HTML::TreeBuilder->new;
	$doc->parse($res->content);
	$doc->eof();

	print "Playlist HTML parsed\n";

	my @things = $doc->look_down("class", "playlist-table");
	my $resultant = "";

	foreach(@things) {
		my @trs = $_->look_down("_tag", "tr");
		$resultant.=yamlizeEntry($_) foreach @trs;
	}

	$doc->delete();

	print "Resultant built (".(length $resultant)." octets)\n";
	my @vs = localtime(time() + 2*60*60);

	if($curname gt $lastdate ||
	   length $resultant > $lastsize ||
	   (length $resultant < $lastsize &&
	    $vs[1] >5 &&
	    $vs[1] < 55)) {
		print "Resultant changed size from $lastsize to ".(length $resultant)." octets\n";
		$lastdate = $curname;
		$lastsize = length $resultant;

		open YME, ">$ydir${curname}.yaml" or next;
		print YME $resultant;
		close YME;

		print "Resultant written to $ydir${curname}.yaml\n";

		unlink "${ydir}current.yaml";
		symlink "$ydir${curname}.yaml", "${ydir}current.yaml";

		print "${ydir}current.yaml updated to point to $ydir$curname\n";
	} elsif($curname eq $lastdate && length $resultant < $lastsize) {
		print "Daily resultant changed size from $lastsize to ".(length $resultant)." octets\n";
		print "Skipping update for a few minutes to let things stabilize...\n";
	}
}

exit;

sub yamlizeEntry {
	my $entrynode = shift;

	my @t_n = $entrynode->look_down("class", "time");
	my $time = undef;
	$time = $t_n[0]->as_trimmed_text() if scalar @t_n;
	
	my @o_n = $entrynode->look_down("class", "artist");
	my @o_c = ();
	@o_c = $o_n[0]->content_list() if scalar @o_n;
	
	my $composer = undef;
	my $title = undef;
	my $publication = undef;
	my @performers = ();

	my $spot = 0;
	my $curline = "";
	my $pdot = undef;

	foreach(@o_c) {
		if(ref $_ eq "") {
			$pdot = 1 if /\xA0/;
			s/^\s+//;
			s/\s+$//;
			s/\xA0(.*)$/ [$1]/;
			$curline.=$_;
		} elsif($_->tag() eq "br") {
			if($spot == 0) {
				if($curline =~ /^(.*?) - (.*)$/) {
					$composer = $1;
					$title = $2;
				} else {
					$title = $curline;
				}	
			} elsif(defined $pdot) {
				$publication = $curline;
			} elsif($curline eq "") {
				# do nothing
			} else {
				push @performers, $curline;
			}
			
			++$spot;
			$curline = "";
			$pdot = undef;
		} elsif($_->tag() eq "a") {
			# nothing for links
		} else {
			my $t = $_->as_trimmed_text();
			$pdot = 1 if $t =~ /\xA0/;

			$t =~ s/^\s+//;
			$t =~ s/\s+$//;
			$t =~ s/\xA0(.*)$/ [$1]/;
			$curline.=$t;
		}
	}

	if($spot == 0) {
		if($curline =~ /^(.*?) - (.*)$/) {
			$composer = $1;
			$title = $2;
		} else {
			$title = $curline;
		}
	}


#	print "Found time $time\n" if defined $time;
#	print "Found composer $composer\n" if defined $composer;
#	print "Found title $title\n" if defined $title;
#	print "Found performer $_\n" foreach(@performers);
#	print "Found publication $publication\n" if defined $publication;
#	print "\n";
#	return;

	$time =~ s/'/''/g;
	$composer =~ s/'/''/g if defined $composer;
	$title =~ s/'/''/g;
	$publication =~ s/'/''/g if defined $publication;
	s/'/''/g foreach @performers;

	my $rt = "- \n  time: '$time'\n";
	$rt.="  composer: '$composer'\n" if defined $composer;
	$rt.="  title: '$title'\n" if defined $title;
	$rt.="  publication: '$publication'\n" if defined $publication;
	$rt.="  performers:\n";
	$rt.="    - '$_'\n" foreach @performers;

	return $rt;
}



