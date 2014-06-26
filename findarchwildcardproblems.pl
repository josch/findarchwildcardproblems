#!/usr/bin/perl

use strict;
use warnings;

# print invalid architecture wildcards (doesnt match any existing architecture)
# and duplicate wildcards (an architecture is matched by more than one
# wildcard) in build dependencies, conflicts, the architecture field and in
# binary packages listed in the Package-List field

use Dpkg::Control;
use Dpkg::Compression::FileHandle;
use Dpkg::Deps;
use List::MoreUtils qw{any};
use List::Util qw{first};
use Dpkg::Arch qw(debarch_is);

my $desc = $ARGV[0]; # /home/josch/gsoc2012/bootstrap/tests/sid-sources-20140101T000000Z
if (not defined($desc)) {
    die "need filename";
}
my $fh = Dpkg::Compression::FileHandle->new(filename => $desc);

my @debarches = ("amd64", "armel", "armhf", "hurd-i386", "i386", "kfreebsd-amd64", "kfreebsd-i386", "mips", "mipsel", "powerpc", "s390x", "sparc",
"alpha", "arm64", "hppa", "m68k", "powerpcspe", "ppc64", "sh4", "sparc64", "x32");

while (1) {
    my $cdata = Dpkg::Control->new(type => CTRL_INDEX_SRC);
    last if not $cdata->parse($fh, $desc);
    my $pkgname = $cdata->{"Package"};
    next if not defined($pkgname);
    my @depfields = ('Build-Depends', 'Build-Depends-Indep', 'Build-Depends-Arch',
        'Build-Conflicts', 'Build-Conflicts-Indep', 'Build-Conflicts-Arch');
    # search for invalid arches in the dependency and conflict fields
    foreach my $depfield (@depfields) {
        my $dep_line = $cdata->{$depfield};
        next if not defined($dep_line);
        foreach my $dep_and (split(/\s*,\s*/m, $dep_line)) {
            my @or_list = ();
            foreach my $dep_or (split(/\s*\|\s*/m, $dep_and)) {
                my $dep_simple = Dpkg::Deps::Simple->new($dep_or);
                my $depname = $dep_simple->{package};
                next if not defined($depname);
                my $arches = $dep_simple->{arches};
                next if not defined($arches);
                # find wildcards that do not match any existing architecture
                foreach my $arch (@{$arches}) {
                    $arch =~ s/^!//;
                    next if (any {debarch_is($_,$arch)} @debarches);
                    print "ID: $pkgname $arch $depname\n";
                }
                # search for duplicate arches in arch restrictions
                # set match frequency to zero for all arches
                my %matchfreq = ();
                foreach my $arch (@debarches) {
                    $matchfreq{$arch} = 0;
                }
                # find duplicates
                foreach my $arch (@{$arches}) {
                    $arch =~ s/^!//;
                    foreach my $a (@debarches) {
                        if (debarch_is($a, $arch)) {
                            $matchfreq{$a} += 1;
                        }
                    }
                }
                # print duplicate matches
                foreach my $arch (@debarches) {
                    if ($matchfreq{$arch} > 1) {
                        print "DD: $pkgname $arch $depname\n";
                    }
                }
            }
        }
    }
    # search for invalid arches in Architecture field
    my $architecture = $cdata->{"Architecture"};
    if (defined($architecture)) {
        # find wildcards that do not match any existing architecture
        foreach my $arch (split(/\s+/m, $architecture)) {
            next if ($arch eq "all");
            next if (any {debarch_is($_,$arch)} @debarches);
            print "IA: $pkgname $arch\n";
        }
        # search for duplicate arches in Architecture field
        # set match frequency to zero for all arches
        my %matchfreq = ();
        foreach my $arch (@debarches) {
            $matchfreq{$arch} = 0;
        }
        # find duplicates
        foreach my $arch (split(/\s+/m, $architecture)) {
            next if ($arch eq "all");
            foreach my $a (@debarches) {
                if (debarch_is($a, $arch)) {
                    $matchfreq{$a} += 1;
                }
            }
        }
        # print duplicate matches
        foreach my $arch (@debarches) {
            if ($matchfreq{$arch} > 1) {
                print "DA: $pkgname $arch\n";
            }
        }
    }
    # gather the architectures of the generated binary packages
    my $packagelist = $cdata->{"Package-List"};
    if (defined($packagelist)) {
        foreach my $line (split(/\n/m, $packagelist)) {
            my $architecture = first { /^arch=/ } split(/\s+/m, $line);
            next if (not defined($architecture));
            $architecture =~ s/^arch=//;
            # find wildcards that do not match any existing architecture
            foreach my $arch (split(/,/m, $architecture)) {
                next if ($arch eq "all");
                next if (any {debarch_is($_,$arch)} @debarches);
                print "IB: $pkgname $arch\n";
            }
            # search for duplicate arches in Architecture field
            # set match frequency to zero for all arches
            my %matchfreq = ();
            foreach my $arch (@debarches) {
                $matchfreq{$arch} = 0;
            }
            # find duplicates
            foreach my $arch (split(/,/m, $architecture)) {
                next if ($arch eq "all");
                foreach my $a (@debarches) {
                    if (debarch_is($a, $arch)) {
                        $matchfreq{$a} += 1;
                    }
                }
            }
            # print duplicate matches
            foreach my $arch (@debarches) {
                if ($matchfreq{$arch} > 1) {
                    print "DB: $pkgname $arch\n";
                }
            }
        }
    }
}
