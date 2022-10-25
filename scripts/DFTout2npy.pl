=b
Usage: perl DFTout2npy.pl "folder path of sout file" "folder path of converted npy files"
This script is for QE only
=cut
use warnings;
use strict;
use Data::Dumper;

my $dftBE_all =  -1865.954065*16;#-1935.38795387896*16;#number need to know or pass the minus sum
my $expBE_be = -6.81*16;


#print "\$ARGV[0]:$ARGV[0] and \$ARGV[1]: $ARGV[1]\n";
#unless($ARGV[0] or $ARGV[1]){print "\$ARGV[0]:$ARGV[0] and \$ARGV[1]:$ARGV[1]\n";die "You need to provide DFT sout file path and npy out path\n";}
#system("mkdir -p $ARGV[1]");#npy output folder path
#die "cannot create $ARGV[1] for npy output folder\n" unless(-d $ARGV[1]);
my $npyout_path = "../dp_train/initial/00/";
my $sout_path = "../DFT_sout/00/";

#for QE convertion
my $ry2eV = 13.605693009;
my $bohr2ang = 0.52917721067;
my $kbar2bar = 1;#000.;
my $kbar2evperang3 = 1e3 / 1.602176621e6;
my $force_convert = $ry2eV / $bohr2ang;
#../DFT_sout/00/
#../dp_train/initial/00/
# all sout files should have the same atom number and corresponding element types.
my @out = <$sout_path/*.sout>;# all DFT output files through slurm
die "No DFT sout file in $ARGV[0]\n" unless(@out);

@out = sort @out;
#loop over all sout files in the following:
#     number of atoms/cell      =           16
###******from type.raw
my $natom = `cat $out[0]|sed -n '/number of atoms\\/cell/p'|awk '{print \$5}'`;	
chomp $natom;
die "You don't get the Atom Number in the DFT sout file!!!\n" unless($natom);

# The following five arrays are used for collecting data from all sout files
my @eraw;#energy.npy
my @vraw;#virial.npy need to check further!!!
my @fraw;#force.npy
my @craw;#coord.npy
my @braw;#box.npy

my @npy = ("energy","virial","force","coord","box");

my %raw_ref = (
energy => \@eraw,
virial => \@vraw,
force => \@fraw,
coord => \@craw,
box => \@braw
);
for my $id (0..$#out){	
	open my $all ,"< $out[$id]";
	my @all = <$all>;
	close($all);
################# energy ############
##!    total energy              =    (-158.01049803) Ry
	my @totalenergy = grep {if(m/^\s*!\s*total energy\s*=\s*([-+]?\d*\.?\d*)/){$_ = $1*$ry2eV - $dftBE_all + $expBE_be;}} @all;
    #my	$lmpE = (($totE - $sumDFTatomE) + $sumLMPatomE) / $atomnumber; #use in MS perl
    die "no total energy was found in $out[$id]\n" unless (@totalenergy);
    for (@totalenergy){chomp;push @eraw,$_}
	my $energyNo = @totalenergy;
	#for (1..@eraw){my $id = $_ -1; print "$id $eraw[$id]\n";}
	
###virial (kbar)  three data for each line
#   0.00000058  -0.00000001  -0.00000003            (0.09)       (-0.00)       (-0.00)
	my @totalstress = `grep -A 3 "total   stress" $out[$id]`;
	chomp @totalstress; 
	my @virial;
	#print @totalstress;
	for(@totalstress){
	  if(m/^\s+[-+]?\d+\.?\d+\s+[-+]?\d+\.?\d+\s+[-+]?\d+\.?\d+\s+([-+]?\d+\.?\d+)\s+([-+]?\d+\.?\d+)\s+([-+]?\d+\.?\d+)/){
			push @virial, [$1*$kbar2bar,$2*$kbar2bar,$3*$kbar2bar];
	  }	    
	}
    die "no virial was found in $out[$id]\n" unless (@virial);
    my $virtalNo = @virial/3;
	die "virial set number is not equal to energy number in $out[$id]\n" if ($energyNo != $virtalNo);

	for my $idv (1..@virial/3){#@virial has three elements
		my $temp = ($idv -1) * 3;
		chomp (@{$virial[$temp]}[0..2],@{$virial[$temp + 1]}[0..2],@{$virial[$temp + 2]}[0..2]);
		#print "$idv: @{$virial[$temp]}[0..2],@{$virial[$temp + 1]}[0..2],@{$virial[$temp + 2]}[0..2]\n";
		push   @vraw, [@{$virial[$temp]}[0..2],@{$virial[$temp + 1]}[0..2],@{$virial[$temp + 2]}[0..2]];
	}
	#for (1..@vraw){my $id = $_ -1; print "$id: @{$vraw[$id]}\n";}

############## force ############   #Ry/au
##     atom    1 type  1   force =     0.00000466    0.00000837    0.00000332
	my @force = grep {if(m/^.+force =\s+([-+]?\d+\.?\d+)\s+([-+]?\d+\.?\d+)\s+([-+]?\d+\.?\d+)/){
			$_ = [$1*$force_convert,$2*$force_convert,$3*$force_convert];}} @all;
    my $forceNo = @force/$natom;# frame number
	die "force set number $forceNo is not equal to energy number in $out[$id]\n" if ($energyNo != $forceNo);
	
	for my $idf (1..@force/$natom){# loop over frames
		#print "$_ @{$force[$_ -1]}[0..2]\n";
		my $temp = ($idf - 1) * $natom;# beginning id of each force set for a frame 
		my @temp; #collecting all forces of a frame
		for my $idf1 ($temp..$temp + $natom -1){
			@temp = (@temp,@{$force[$idf1]}[0..2]);#three elements to merger
		}
		chomp @temp;
		my $tempNo = @temp/3;
		# print "\$tempNo:$tempNo,". scalar(@temp) ."\n";
		die "force set number of a frame is not equal to atom number in $out[$id]\n" if ($natom != $tempNo);
		push @fraw,[@temp];
	}
	#for (1..@fraw){my $id = $_ -1; print "$id: @{$fraw[$id]}\n";}

############## coord ############
##ATOMIC_POSITIONS (angstrom)        
##Al           -0.0000004209       -0.0000004098       -0.0000002490
	my @coord = `grep -A $natom "ATOMIC_POSITIONS (angstrom)" $out[$id]`;
	chomp @coord;
	my @tempcoord;
	for(@coord){
		if(m/^\w+\s+([-+]?\d+\.?\d+)\s+([-+]?\d+\.?\d+)\s+([-+]?\d+\.?\d+)/){
			push @tempcoord, [$1,$2,$3];
		}	
	}
    die "no coord was found in $out[$id]\n" unless (@tempcoord);
	my $tempcoord = @tempcoord/$natom;
	die "coord set number $tempcoord is not equal to energy number in $out[$id]\n" if ($tempcoord != $energyNo);

	for my $idc (1..@tempcoord/$natom){#@virial has three elements
		my $temp = ($idc - 1) * $natom;# beginning id of each force set for a frame 
		my @temp; #collecting all forces of a frame
		for my $idc1 ($temp..$temp + $natom -1){
			@temp = (@temp,@{$tempcoord[$idc1]}[0..2]);#three elements to merger
		}
		chomp @temp;
		my $tempNo = @temp/3;
		# print "\$tempNo:$tempNo,". scalar(@temp) ."\n";
		die "coor set number of a frame is not equal to atom number in $out[$id]\n" if ($natom != $tempNo);
		push @craw,[@temp];
	}
	#for (1..@craw){my $id = $_ -1; print "$id: @{$craw[$id]}\n";}
############### box ############
###CELL_PARAMETERS (angstrom)
###4.031848986   0.000000009   0.000000208
	my @CellVec = `grep -A 3 "CELL_PARAMETERS (angstrom)" $out[$id]`;
	chomp @CellVec; 
	my @cell;
	for (@CellVec){
	  if(m/^\s*([-+]?\d+\.?\d+)\s+([-+]?\d+\.?\d+)\s+([-+]?\d+\.?\d+)/){
			push @cell, [$1,$2,$3];
	  }	
	}    
#	
    die "no cell vector was found in $out[$id]\n" unless (@cell);
    my $cellNo = @cell/3;
	die "cell vestor set number is not equal to energy number in $out[$id]\n" if ($energyNo != $cellNo);

	for my $idc (1..@cell/3){#@virial has three elements
		my $temp = ($idc -1) * 3;
		chomp (@{$cell[$temp]}[0..2],@{$cell[$temp + 1]}[0..2],@{$cell[$temp + 2]}[0..2]);
		#print "$idv: @{$virial[$temp]}[0..2],@{$virial[$temp + 1]}[0..2],@{$virial[$temp + 2]}[0..2]\n";
		push   @braw, [@{$cell[$temp]}[0..2],@{$cell[$temp + 1]}[0..2],@{$cell[$temp + 2]}[0..2]];
	}
}

for my $f (@npy){
	my $filepath = "$npyout_path/$f.raw";
	open my $t ,">$filepath";
    my @raw = @{ $raw_ref{$f} };
	#print "\n***$f\n";
	for my $id (0..$#raw){
		my $r = $raw[$id];
		if ($f eq "energy"){
			chomp $r;
			print $t "$r";
			print $t "\n" unless($id == $#raw); 
	    }
		else{
			chomp @{$r};
			print $t "@{$r}";# dereference
			print $t "\n" unless($id == $#raw); 
		}
	}
	close($t);
}


  `python -c 'import numpy as np; data = np.loadtxt("$npyout_path/box.raw"   , ndmin = 2); data = data.astype (np.float32); np.save ("$npyout_path/box",    data)'`;
#  python -c 'import numpy as np; data = np.loadtxt("coord.raw" , ndmin = 2); data = data.astype (np.float32); np.save ("coord",  data)'
#  python -c \
#'import numpy as np; import os.path; 
#if os.path.isfile("energy.raw"): 
#   data = np.loadtxt("energy.raw"); 
#   data = data.astype (np.float32); 
#   np.save ("energy", data)
#'
#  python -c \
#'import numpy as np; import os.path; 
#if os.path.isfile("force.raw" ): 
#   data = np.loadtxt("force.raw", ndmin = 2); 
#   data = data.astype (np.float32); 
#   np.save ("force",  data)
#'
#  python -c \
#'import numpy as np; import os.path; 
#if os.path.isfile("virial.raw"): 
#   data = np.loadtxt("virial.raw", ndmin = 2); 
#   data = data.astype (np.float32); 
#   np.save ("virial", data)
#'
#  python -c \
#'import numpy as np; import os.path; 
#if os.path.isfile("atom_ener.raw"): 
#   data = np.loadtxt("atom_ener.raw", ndmin = 2); 
#   data = data.astype (np.float32); 
#   np.save ("atom_ener", data)
#'
#  python -c \
#'import numpy as np; import os.path; 
#if os.path.isfile("fparam.raw"): 
#   data = np.loadtxt("fparam.raw", ndmin = 2); 
#   data = data.astype (np.float32); 
#   np.save ("fparam", data)
#'
#  rm *.raw
#  cd ../