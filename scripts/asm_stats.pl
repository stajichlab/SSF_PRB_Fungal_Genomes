#!/usr/bin/env perl

use File::Spec;
use strict;
use warnings;
use Getopt::Long;

my %stats;
my $debug = 0;

GetOptions('v|verbose' => \$debug);

my $BUSCO_dir      = 'BUSCO';
my $BUSCO_pep      = 'BUSCO_pep';
my $read_map_stat  = 'mapping_report';
my $SAMPLES        = 'samples.csv';
my $dir            = shift || 'genomes';

my (@header, %header_seen);
my (@mappingrun, @busco_rerun);

opendir(DIR, $dir) || die "Cannot open dir $dir: $!";

# Collect all stat headers first so they appear before BUSCO/mapping columns
# regardless of which file is processed first.
my (@asm_stat_headers_seen);

# Two-pass: first collect stats, then add BUSCO/mapping columns once.
my %stems_found;

foreach my $file ( sort readdir(DIR) ) {
    # Match: ID.stats.txt  OR  ID.sorted.stats.txt
    next unless $file =~ /^(\S+?)(?:\.sorted)?\.stats\.txt$/;
    my $stem      = $1;                  # always the clean ID (no .sorted)

    $stems_found{$stem} = "$dir/$file";
}
closedir(DIR);

foreach my $stem ( sort keys %stems_found ) {
    my $statfile = $stems_found{$stem};
    warn("Processing $statfile (stem=$stem)\n") if $debug;

    open(my $fh, '<', $statfile) || die "Cannot open $statfile: $!";
    while (<$fh>) {
        next if /^\s*$/;
        s/^\s+//;
        chomp;
        if ( /\s*(.+)\s+=\s+(\d+(?:\.\d+)?)/ ) {
            my ($name, $val) = ($1, $2);
            $name =~ s/\s+$//;
            $name =~ s/\s+/_/g;
            $stats{$stem}{$name} = $val;
            unless ($header_seen{$name}) {
                push @header, $name;
                $header_seen{$name} = 1;
            }
        }
    }
    close $fh;
}

# Add BUSCO genome columns
if ( -d $BUSCO_dir ) {
    push @header, qw(BUSCO_Complete BUSCO_Single BUSCO_Duplicate
                     BUSCO_Fragmented BUSCO_Missing BUSCO_NumGenes);

    foreach my $stem ( sort keys %stems_found ) {
        my $buscosub = File::Spec->catdir($BUSCO_dir, $stem);
        if ( -d $buscosub ) {
            opendir(my $dh, $buscosub) || die "Cannot open $buscosub: $!";
            my @busco_files = grep { /short_summary\.specific\.[^.]+\.\S+\.txt$/ }
                              map  { File::Spec->catfile($buscosub, $_) }
                              readdir($dh);
            closedir($dh);

            if (@busco_files) {
                # Use the first (should only be one per run)
                _parse_busco_summary($busco_files[0], $stem, 'BUSCO', \%stats);
            } else {
                warn("Cannot find BUSCO short_summary in $buscosub\n");
                push @busco_rerun, _sample_index($stem, $SAMPLES);
            }
        } else {
            warn("BUSCO not run yet for $stem (expected $buscosub)\n");
            push @busco_rerun, _sample_index($stem, $SAMPLES);
        }
    }
}

# Add BUSCO protein columns
if ( -d $BUSCO_pep ) {
    push @header, qw(BUSCOP_Complete BUSCOP_Single BUSCOP_Duplicate
                     BUSCOP_Fragmented BUSCOP_Missing BUSCOP_NumGenes);

    foreach my $stem ( sort keys %stems_found ) {
        my $buscosub = File::Spec->catdir($BUSCO_pep, $stem);
        if ( -d $buscosub ) {
            opendir(my $dh, $buscosub) || die "Cannot open $buscosub: $!";
            my @busco_files = grep { /short_summary\.specific\.[^.]+\.\S+\.txt$/ }
                              map  { File::Spec->catfile($buscosub, $_) }
                              readdir($dh);
            closedir($dh);

            if (@busco_files) {
                _parse_busco_summary($busco_files[0], $stem, 'BUSCOP', \%stats);
            } else {
                warn("Cannot find BUSCOP short_summary in $buscosub\n");
            }
        } else {
            warn("BUSCO_pep not run yet for $stem (expected $buscosub)\n") if $debug;
        }
    }
}

# Add read-mapping columns
if ( -d $read_map_stat ) {
    push @header, qw(Total_Reads Mapped_reads Average_Coverage);

    foreach my $stem ( sort keys %stems_found ) {
        my $sumstatfile = File::Spec->catfile($read_map_stat,
                                              "${stem}.bbmap_summary.txt");
        warn("sumstat is $sumstatfile\n") if $debug;

        if ( -f $sumstatfile ) {
            open(my $fh, '<', $sumstatfile) || die "Cannot open $sumstatfile: $!";
            my $read_dir  = 0;
            my $base_count = 0;
            $stats{$stem}{'Mapped_reads'} = 0;
            while (<$fh>) {
                if    ( /Read\s+(\d+)\s+data:/ )                                      { $read_dir = $1 }
                elsif ( $read_dir && /^mapped:\s+\S+\s+(\d+)\s+\S+\s+(\d+)/ )        { $base_count += $2; $stats{$stem}{'Mapped_reads'} += $1 }
                elsif ( /^Reads Used:\s+(\S+)/ )                                       { $stats{$stem}{'Total_Reads'} = $1 }
            }
            close $fh;
            $stats{$stem}{'Average_Coverage'} =
                (exists $stats{$stem}{'TOTAL_LENGTH'} && $stats{$stem}{'TOTAL_LENGTH'} > 0)
                ? sprintf("%.1f", $base_count / $stats{$stem}{'TOTAL_LENGTH'})
                : 0;
        } else {
            warn("Cannot find $sumstatfile\n");
            push @mappingrun, _sample_index($stem, $SAMPLES);
        }
    }
}

# Output
print join("\t", 'SampleID', @header), "\n";
foreach my $stem ( sort keys %stats ) {
    print join("\t", $stem, map { $stats{$stem}{$_} // 'NA' } @header), "\n";
}

if (@busco_rerun) {
    warn("BUSCO rerun: -a ", join(",", sort { $a <=> $b } @busco_rerun), "\n");
}
if (@mappingrun) {
    warn("mapping rerun: -a ", join(",", sort { $a <=> $b } @mappingrun), "\n");
}

# ---- helpers ----

sub _parse_busco_summary {
    my ($file, $stem, $prefix, $stats) = @_;
    open(my $fh, '<', $file) || die "Cannot open $file: $!";
    while (<$fh>) {
        # BUSCO 5.x summary line:
        # C:98.5%[S:97.2%,D:1.3%],F:0.5%,M:1.0%,n:758
        if (/^\s+C:(\d+\.?\d*)\%\[S:(\d+\.?\d*)%,D:(\d+\.?\d*)%\],F:(\d+\.?\d*)%,M:(\d+\.?\d*)%,n:(\d+)/) {
            $stats->{$stem}{"${prefix}_Complete"}    = $1;
            $stats->{$stem}{"${prefix}_Single"}      = $2;
            $stats->{$stem}{"${prefix}_Duplicate"}   = $3;
            $stats->{$stem}{"${prefix}_Fragmented"}  = $4;
            $stats->{$stem}{"${prefix}_Missing"}     = $5;
            $stats->{$stem}{"${prefix}_NumGenes"}    = $6;
            last;
        }
    }
    close $fh;
}

sub _sample_index {
    my ($stem, $samples_file) = @_;
    # Find 1-based data row index of this sample in samples.csv (header excluded)
    open(my $fh, '<', $samples_file) || do { warn "Cannot open $samples_file\n"; return undef };
    my $idx = 0;
    while (<$fh>) {
        next if $. == 1;   # skip header
        $idx++;
        chomp;
        my ($id) = split /,/, $_, 2;
        return $idx if $id eq $stem;
    }
    close $fh;
    warn("Cannot find $stem in $samples_file\n");
    return undef;
}
