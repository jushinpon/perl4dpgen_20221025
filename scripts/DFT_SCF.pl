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
    #print "\$str: $str\n";
    my $elements =`cat $mainPath/initial/$str/elements.dat|egrep -v "#|^\$"`;#get element types of all atoms
    $elements  =~ s/^\s+|\s+$//;#remove beginnig and end empty space
	my @elements = split (/\s+/,$elements);#id -> element type
    die "No atoms in the elements.dat for DFT SCF\n" unless(@elements);
    my $atom_num =  @elements;#total atom number
    my %unique = map { $_ => 1 } @elements;#remove duplicate ones
    my @used_element = keys %unique;
    my $ntype = @used_element; # totoal element type
    #########################     elements.pm       #####################
    my %used_element;
    for (@used_element){
        chomp;
         #density (g/cm3), arrangement, mass, lat a , lat c
         @{$used_element{$_}} = &elements::eleObj("$_"); 
    }
   
    my $json;
    {
        local $/ = undef;
        open my $fh, '<', $QE_pot_json;
        $json = <$fh>;
        close $fh;
    }
    my $decoded = decode_json($json);
    ######   cutoff   #######
    my @rho_cutoff;
    my @cutoff;
    for (@used_element){
     push @rho_cutoff,$decoded->{$_}->{rho_cutoff};
     push @cutoff,$decoded->{$_}->{cutoff};
    }
    # for keeping the largest ones only
    @rho_cutoff = sort {$a<=>$b} @rho_cutoff;
    @cutoff = sort {$a<=>$b} @cutoff;

    my $kpoint = `cat $mainPath/initial/$str/kpoints.dat|egrep -v "#|^\$"`;#get kpoint number of this system
    chomp $kpoint;
    die "No kpoints.dat in $mainPath/initial/$str\n" unless($kpoint);
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
        `cp $mainPath/scripts/QE_script.in $dftscript`;
        ###ATOMIC_SPECIES###
        for (@used_element){
            `sed -i '/ATOMIC_SPECIES/a $_  ${$used_element{$_}}[2]  $decoded->{$_}->{filename}' $dftscript`;
        }
        ##starting_magnetization###
        for (1..@used_element){
          `sed -i '/nspin = 2/a starting_magnetization($_) =  2.00000e-01' $dftscript`;
        } 
        ### cutoff ### (not modify them dynamically)
        #`sed -i 's:^ecutwfc.*:ecutwfc = $cutoff[-1]:' $dftscript`;
        #`sed -i 's:^ecutrho.*:ecutrho = $rho_cutoff[-1]:' $dftscript`;    
        ###type###
        `sed -i 's:^ntyp.*:ntyp = $ntype:' $dftscript`;    
        ###atoms###        
        `sed -i 's:^nat.*:nat = $atom_num:' $dftscript`;
        ## cell parameter ####
        my $xlo_bound = `sed -n '/ITEM: BOX BOUNDS.*/{n;p}' $cfg | awk '{print \$1}'`;
        my $xhi_bound = `sed -n '/ITEM: BOX BOUNDS.*/{n;p}' $cfg | awk '{print \$2}'`;
        my $xy = `sed -n '/ITEM: BOX BOUNDS.*/{n;p}' $cfg | awk '{print \$3}'`;
        chomp $xy;

        my $ylo_bound = `sed -n '/ITEM: BOX BOUNDS.*/{n;n;p}' $cfg | awk '{print \$1}'`;
        my $yhi_bound = `sed -n '/ITEM: BOX BOUNDS.*/{n;n;p}' $cfg | awk '{print \$2}'`;
        my $xz = `sed -n '/ITEM: BOX BOUNDS.*/{n;n;p}' $cfg | awk '{print \$3}'`;
        chomp $xz;

        my $zlo_bound = `sed -n '/ITEM: BOX BOUNDS.*/{n;n;n;p}' $cfg | awk '{print \$1}'`;
        my $zhi_bound = `sed -n '/ITEM: BOX BOUNDS.*/{n;n;n;p}' $cfg | awk '{print \$2}'`;
        my $yz = `sed -n '/ITEM: BOX BOUNDS.*/{n;n;n;p}' $cfg | awk '{print \$3}'`;
        chomp $yz;

        my $xlo = $xlo_bound - min(0.0,$xy,$xz,($xy+$xz));
        my $xhi = $xhi_bound - max(0.0,$xy,$xz,($xy+$xz));
        my $ylo = $ylo_bound - min(0.0,$yz);
        my $yhi = $yhi_bound - max(0.0,$yz);

        my $lx = $xhi - $xlo ;
        my $ly = $yhi - $ylo ;
        my $lz = $zhi_bound - $zlo_bound ;
  
        `sed -i '/CELL_PARAMETERS {angstrom}/a  $xz $yz $lz' $dftscript` ;
        `sed -i '/CELL_PARAMETERS {angstrom}/a  $xy $ly 0' $dftscript` ;
        `sed -i '/CELL_PARAMETERS {angstrom}/a  $lx 0 0' $dftscript` ;
	    #kpoint
        `sed -i '/K_POINTS {automatic}/a  $kpoint' $dftscript` ;
        #coordinates
        my @coordinates = `grep -A $atom_num "ITEM: ATOMS id type x y z" $cfg|egrep -v "ITEM:|^\$"`;
        chomp @coordinates;
        die "coordinate set number is unequal to atom number" unless($atom_num == @coordinates);
        my @dft_coors;
        for my $coor (@coordinates){
            #16 1 4.83297 4.8497 4.86631
            $coor  =~ s/^\s+|\s+$//;#remove beginnig and end empty space
            #Mo XX XX XX
	        my @temp = split (/\s+/,$coor);
            chomp @temp;
            # lmp id from 1, the following is also used for sorting
            my $id = $temp[0] - 1;
            $dft_coors[$id] = "$elements[$id] $temp[2] $temp[3] $temp[4]";
        }
        #modify dft input after sorting
        for my $coor (reverse @dft_coors){
            `sed -i '/ATOMIC_POSITIONS {angstrom}/a $coor' $dftscript` ;
        }
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