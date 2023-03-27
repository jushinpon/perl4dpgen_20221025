=b
conduct lammps and then label data files within the deviation criterions. 
=cut
use warnings;
use strict;
use JSON::PP;
use Data::Dumper;
use List::Util qw(min max);
use Cwd;
use POSIX;
use Parallel::ForkManager;
use lib '.';#assign pm dir
use elements;#all setting package

sub DFT_SCF{

my ($ss_hr,$scf_hr,$iter_ar) = @_;
my $forkNo = 1;#although we don't have so many cores, only for submitting jobs into slurm
my $pm = Parallel::ForkManager->new("$forkNo");
my $mainPath = $ss_hr->{main_dir};# main path of dpgen folder
my $currentPath = $ss_hr->{script_dir};
my $debug = $ss_hr->{debug};
my $QE_pot_json = $ss_hr->{QE_pot_json};
`rm -rf $mainPath/DFT_output/`;#remove all old files and folders
my $dft_exe = $ss_hr->{dft_exe};#dft exe 

my $iter = "iter". sprintf("%03d",$ss_hr->{iter});
my @labelled_dir = `find $mainPath/lmp_label -maxdepth 2 -mindepth 2 -type d -name "labelled"`;
chomp @labelled_dir;
for my $dir (@labelled_dir){
    $dir =~ /.+lmp_label\/(T\d+.+)\/labelled/;
    chomp $1;#folder name with sub-folder "labelled"
    die "No DFT_SCF output folder\n" unless($1);
    #$1: T50-P1-R500-bcc_bulk
    my $thermostate = $1;
    $thermostate =~ /T\d+-P\d+-R\d+-(.+)/;
    chomp $1;
    #my $str = (split "-",$1)[-1];# need this to find required data in initial folder (not good)
    my $str = $1;# need this to find required data in initial folder
    my @QEin_temp = `cat $mainPath/initial/$str/$str.in|grep -v '^[[:space:]]*\$'`;
    map { s/^\s+|\s+$//g; } @QEin_temp; 
    die "No inform was got in $mainPath/initial/$str/$str.in\n" unless(@QEin_temp);
    #get the lines of key words
    my $calculation;
    my $nat;
    my $ATOMIC_POSITIONS;
    my $CELL_PARAMETERS;
    for my $i (0..$#QEin_temp){
        my $temp = $QEin_temp[$i];
        if($temp =~ /calculation/){$calculation = $i;}
        elsif($temp =~ /nat/){$temp =~ /nat\s*=\s*(\d+)/;$nat = $1;}
        elsif($temp =~ /ATOMIC_POSITIONS/){$ATOMIC_POSITIONS = $i;}
        elsif($temp =~ /CELL_PARAMETERS/){$CELL_PARAMETERS = $i;}
        #print "$i : $temp\n";
    } 

    if(!$calculation){die "no \$calculation was got in $mainPath/initial/$str/$str.in\n";}
    elsif(!$nat){die "no \$nat was got in $mainPath/initial/$str/$str.in\n";}
    elsif(!$ATOMIC_POSITIONS){die "no \$ATOMIC_POSITIONS was got in $mainPath/initial/$str/$str.in\n";}
    elsif(!$CELL_PARAMETERS){die "no \$CELL_PARAMETERS was got in $mainPath/initial/$str/$str.in\n";}

    $QEin_temp[$calculation] = "calculation = 'scf'";#could be vc-md, but scf is needed! 
 
 # cfg is used for cell information and atom coordinates of DFT input file
    my @cfg = `find $dir -maxdepth 1 -mindepth 1 -type f -name "*.cfg"`;#find all cfg files in this thermostate
    chomp @cfg;
    for my $cfg (@cfg){
        my $basename = `basename $cfg`;# get basename from a long path
        chomp $basename;
        $basename =~ /(.+)\.cfg/;
        chomp $1;#prefix only
        my $cfg_prefix = $1; 
        my $dftscript_folder = "$mainPath/DFT_output/$thermostate/$cfg_prefix";
        #print "\$dftout_folder:$dftout_folder\n";
        `mkdir -p $dftscript_folder`;
        #die;
        my $DFT_filename = "$cfg_prefix-dft.in";# for DFT filename
        my $slurm_filename = "$cfg_prefix-dft.sh";# for DFT filename
        my $dftscript = "$dftscript_folder/$DFT_filename";
        my $slurm_outscript = "$dftscript_folder/$slurm_filename";
#begin modify dft input
        ## cell parameter ####
        my $xlo_bound = `sed -n '/ITEM: BOX BOUNDS.*/{n;p}' $cfg | awk '{print \$1}'`;
        my $xhi_bound = `sed -n '/ITEM: BOX BOUNDS.*/{n;p}' $cfg | awk '{print \$2}'`;
        my $xy = `sed -n '/ITEM: BOX BOUNDS.*/{n;p}' $cfg | awk '{print \$3}'`;
        chomp ($xlo_bound,$xhi_bound,$xy);
        unless ($xy){$xy = 0.0;}#if no $xy
        my $ylo_bound = `sed -n '/ITEM: BOX BOUNDS.*/{n;n;p}' $cfg | awk '{print \$1}'`;
        my $yhi_bound = `sed -n '/ITEM: BOX BOUNDS.*/{n;n;p}' $cfg | awk '{print \$2}'`;
        my $xz = `sed -n '/ITEM: BOX BOUNDS.*/{n;n;p}' $cfg | awk '{print \$3}'`;
        chomp ($ylo_bound,$yhi_bound,$xz);
        unless ($xz){$xz = 0.0;}#if no $xz
        my $zlo_bound = `sed -n '/ITEM: BOX BOUNDS.*/{n;n;n;p}' $cfg | awk '{print \$1}'`;
        my $zhi_bound = `sed -n '/ITEM: BOX BOUNDS.*/{n;n;n;p}' $cfg | awk '{print \$2}'`;
        my $yz = `sed -n '/ITEM: BOX BOUNDS.*/{n;n;n;p}' $cfg | awk '{print \$3}'`;
        chomp ($zlo_bound,$zhi_bound,$yz);
        unless ($yz){$yz = 0.0;}#if no $yz

        my $xlo = $xlo_bound - min(0.0,$xy,$xz,($xy+$xz));
        my $xhi = $xhi_bound - max(0.0,$xy,$xz,($xy+$xz));
        my $ylo = $ylo_bound - min(0.0,$yz);
        my $yhi = $yhi_bound - max(0.0,$yz);

        my $lx = sprintf("%.6f",$xhi - $xlo) ;
        my $ly = sprintf("%.6f",$yhi - $ylo) ;
        my $lz = sprintf("%.6f",$zhi_bound - $zlo_bound);
        my $zero = sprintf("%.6f",0.0);

        $xy = sprintf("%.6f",$xy); 
        $xz = sprintf("%.6f",$xz); 
        $yz = sprintf("%.6f",$yz); 
        $QEin_temp [$CELL_PARAMETERS + 1] =  "$lx $zero $zero";
        $QEin_temp [$CELL_PARAMETERS + 2] =  "$xy $ly $zero";
        $QEin_temp [$CELL_PARAMETERS + 3] =  "$xz $yz $lz";
        #coordinates
        my @coordinates = `grep -A $nat "ITEM: ATOMS id type x y z" $cfg|egrep -v "ITEM:|^\$"`;
        chomp @coordinates;
        die "QE atom number is unequal to cfg atom number" unless($nat == @coordinates);
        for my $c (0..$#coordinates){
            #16 1 4.83297 4.8497 4.86631
            $coordinates[$c]  =~ s/^\s+|\s+$//;#remove beginnig and end empty space
            #Mo XX XX XX
	        my @temp = split (/\s+/,$coordinates[$c]);
            #2 1 2.94018 4.46825 4.86328
	        my @Ele_temp = split (/\s+/,$QEin_temp[$ATOMIC_POSITIONS + $c + 1]);
            #Na 5.8010875862 1.5546837697 2.2032422412
            #
            chomp @temp;
            # lmp id from 1, the following is also used for sorting
            my $tempx = sprintf("%.6f",$temp[2] - $xlo);
            my $tempy = sprintf("%.6f",$temp[3] - $ylo);
            my $tempz = sprintf("%.6f",$temp[4] - $zlo_bound);#zlo = zlo_bound
            chomp ($tempx,$tempy,$tempz);
            #print "$Ele_temp[0] ($tempx,$tempy,$tempz)\n";
            $QEin_temp[$ATOMIC_POSITIONS + $c + 1] = "$Ele_temp[0] $tempx $tempy $tempz";
        }
        my $QE_in = join("\n",@QEin_temp);
        print "\$dftscript: $dftscript\n";
        #print "$QE_in\n";
        #output QE in file
        open(FH, "> $dftscript") or die $!;
        print FH $QE_in;
        close(FH);
# making slurm script
        `cp $mainPath/scripts/slurm_dft.sh $slurm_outscript`;
        # #modify job name
        `sed -i '/#SBATCH.*--job-name/d' $slurm_outscript`;
        `sed -i '/#sed_anchor01/a #SBATCH --job-name=$cfg_prefix-dft' $slurm_outscript`;
        #modify output file name
        `sed -i '/#SBATCH.*--output/d' $slurm_outscript`;
        `sed -i '/#sed_anchor01/a #SBATCH --output=$cfg_prefix-dft.sout' $slurm_outscript`;
        # #modify script name
        `sed -i '/mpiexec .*/d' $slurm_outscript`;
        my $dft_run = "mpiexec $dft_exe -in $dftscript";
        `sed -i '/#mpiexec_anchor/a $dft_run' $slurm_outscript`;
        chdir("$dftscript_folder");
        system("sbatch $slurm_outscript");
        chdir("$currentPath");               
    } 
}
#die;
### check whether all scf processes are done
my @DFTFolders = `find $mainPath/DFT_output -maxdepth 2 -mindepth 2 -type d -name "*"`;
chomp @DFTFolders;

my $DFTNo = @DFTFolders; # total DFT jobs for this iteration
#print "\@DFTFolders:@DFTFolders\n";
#my $temp = <STDIN>;
print "\n\n#Beginning DFT SCF while loop for the total $DFTNo scf jobs at $iter\n";
my $whileCounter = 0;
my $Counter = 0;
my $failed = 0;
my $elapsed;
while ($whileCounter <= 10000 and $Counter != $DFTNo ){
	sleep(60);
    $whileCounter += 1;
	$Counter = 0;
    $failed = 0;
    $elapsed = 60.0 * $whileCounter;
 if($debug eq "yes"){
    my $mod = $whileCounter % 60;#every 60 min	
    if($mod == 0){#every 60 min
        for (@DFTFolders){	
	    		if( -e "$_/dft_done.txt"){
	    			$Counter += 1;
	    			print "dft scf job in $_ is Done!!!\n";
                }
	    		else{
	    			print "dft scf job in $_ hasn't Done\n";
	    		}				 
	    }
	
        my $min = $elapsed/(60.);
        print "\n****Doing while loop times for dft scf: $whileCounter at $iter\n";
	    print "****Elapsed times: $min min.\n";
	    print "Current number with dft scf jobs done: $Counter from $DFTNo jobs\n\n";
    }
    else{#check every min
        for (@DFTFolders){	
	    	if( -e "$_/dft_done.txt"){
	    		$Counter += 1;
            }
        }
    } 
 }#debug
}#while loop
print "\n\n#####Check all scf calculation results for $iter:\n";
$Counter = 0;
$failed = 0;
for (@DFTFolders){	    		
    if(`cat $_/*.sout|grep "JOB DONE."`){			
	    $Counter++;
	    print "dft scf calculation in $_ is good!!!\n";}
    else{
	    $failed++; 
        print "? dft scf calculation in $_ failed!!!\n";
    }	    		
}
my $convergedNo = 0; 
for (@DFTFolders){
    my @temp = `grep "!" $_/*.sout`;#find "! total energy"
    $convergedNo++ if(@temp);#get the line with "!"
}
$elapsed = $elapsed/60.;
print "#End of DFT SCF while loop after $elapsed min. $convergedNo Good DFT SCF jobs from the total $DFTNo jobs at $iter\n\n";
return $convergedNo;

}# end sub
1;