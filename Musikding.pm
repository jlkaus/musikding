package Musikding;

use strict;
use warnings;

our $laufzeug = "./disc-ctl";
our $cdparloc = "/usr/bin/cdparanoia";
our $flacloc = "/usr/bin/flac";

our $riploc = "/tmp/";


# process the exit status of system
sub dealWithSystemResult {
    my ($s,$cmd) = @_;

    my $rc = 0;
    if($s == -1) {
	die "ERROR: Failed to execute $cmd\n";
    } elsif($s & 127) {
	die "ERROR: $cmd died via signal ".($s & 127)."\n";
    } else {
	$rc = $s >> 8;
    }

    return $rc;
}

# open drive
sub openDrive {
    my ($device) = @_;
    system("$laufzeug -d $device --open");
    return dealWithSystemResult($?);
}

# close drive
sub closeDrive {
    my ($device) = @_;
    system("$laufzeug -d $device --close");
    return dealWithSystemResult($?);
}

# lock drive
sub lockDrive {
    my ($device) = @_;
    system("$laufzeug -d $device --lock");
    return dealWithSystemResult($?);
}

# unlock drive
sub unlockDrive {
    my ($device) = @_;
    system("$laufzeug -d $device --unlock");
    return dealWithSystemResult($?);
}

# mediaChanged drive
sub hasMediaChangedInDrive {
    my ($device) = @_;
    system("$laufzeug -d $device --media-change");
    return dealWithSystemResult($?);
}

# get disc info
sub getDiscInfo {
    my ($device) = @_;

    my @id_data = `$laufzeug -d $device --cd-info`;
    my $rc = dealWithSystemResult($?);

    my $result = {};

    foreach(@id_data) {
	chomp;

	if(/^Musicbrainz-Disc-Id:\s+(.*)$/) {
	    $result->{mbid} = $1;
	} elsif(/^Musicbrainz-Toc:\s+(.*)$/) {
	    $result->{mbtoc} = $1;
	    $result->{mbtoc_list} = [split(/ /,$1)];
	} elsif(/^Freedb-Disc-Id:\s+(.*)$/) {
	    $result->{fdid} = $1;
	} elsif(/^Freedb-Toc:\s+(.*)$/) {
	    $result->{fdtoc} = $1;
	    $result->{fdtoc_list} = [split(/ /,$1)];
	} else {
	    # ignore other crap
	}
    }

    return $result;
}

# drive status
sub getDriveStatus {
    my ($device) = @_;
    system("$laufzeug -d $device --drive-status");
    return dealWithSystemResult($?);
}




# download cddb data
sub downloadFreedbData {
    my ($fdid) = @_;

    # All genres!

    # Put it in the database
}

# download musicbrainz data
sub downloadMusicbrainzData {
    my ($mbid) = @_;

    # Put it in the database
}




# rip disc to waves
sub ripDiscToWave {
    my ($device, $mbid, $track, $estframes) = @_;

    my $filnam = "Q${mbid}".sprintf("%03d",$track);

    # should I verify the file doesn't exist yet? (else delete it)
    if(-e "${riploc}${filnam}.wav") {
	unlink("${riploc}${filnam}.wav");
    }

    # verify the riploc exists
    system("mkdir -p ${riploc}");

    # cdparanoia -d $device -w -e $track FILENAME.wav 2>&1 |
    # cdda2wav -D $device -c 2 -s -x -O wav -t $track -paranoia FILENAME.wav 2>&1 |

    my $sectors=0;
    my $reads=0;
    my $vers=0;
    my $fues=0;
    my $fuas=0;
    my $res=0;
    my $fuds=0;
    my $skips=0;
    my $scratchs=0;

    open(CDPR, "${cdparloc} -d ${device} -w -e ${track} ${riploc}${filnam}.wav 2>&1 |");
    while(<CDPR>) {
	if( /^##:\s*([^\s]+)\s*.*$/ ) {
	    $sectors++	if($1 >= 0);
	    $reads++	if($1 == 0);
	    $vers++	if($1 == 1);
	    $fues++	if($1 == 2);
	    $fuas++	if($1 == 3);
	    $res++	if($1 == 12);
	    $fuds++	if(($1 == 10) || ($1 == 11));
	    $skips++	if($1 == 6);
	    $scratchs++	if(($1 == 4) || ($1 == 5));
	}
    }
    close(CDPR);

    my $exit_status = $? >> 8;

    my $newqual = 100 - 6.04*(5*($fues+$fuas+$res) + 50*($fuds+$scratchs) + 95*$skips)/$estframes;

    if($exit_status != 0) {
	$newqual = $exit_status;
    }

    # should I verify the file exists? (else -1)
    if(!-e "${riploc}${filnam}.wav") {
	if($exit_status == 0) {
	    $exit_status = 255;
	}

	$newqual = 0;
    }

    return ($exit_status, $newqual);
}

# transcode wav to flac
sub transcodeWaveToFlac {
    my ($mbid) = @_;

    # flac --totally-silent -f --delete-input-file --best FILENAME.wav
}

# transcode flac to ogg
sub transcodeFlacToOgg {
    my ($mbid) = @_;

    # oggenc -o OUTPUTFILE.ogg INPUTFILE.flac
}

# tag file
sub tagFile {
    my ($mbid) = @_;

    # tag the flac from the database

}




# database connection management

# database statement prep

# database insert new records

# database update records

# database retrieve records













1;
