=b
Perl version for degen. Developed by Prof. Shin-Pon Ju at NSYSU
open a tmux session first, and then
perl main.pl > ../degen.log

You need to check your deepmd-kit path (dp train and lmp) and QE path for slurm job submission
=cut
use warnings;
use strict;
use JSON::PP;
use Data::Dumper;
use Cwd;
use POSIX;
use Parallel::ForkManager;
use lib '.';#assign pm dir for current dir
use all_settings;# package for all setting

require './DFTout2npy_QE.pl';#QE output to npy files
require './DFT_SCF.pl';
require './lmp_label.pl';
require './dp_train.pl';
require './matplot.pl';
#my $onlyfinal_dptrain = "no";#yes or no (not work currently)
my $initial_trainOnly = "no";#if "yes", only conduct the initial training
my $initial_npyOnly = "yes";#if "yes", only conduct the npy convertion for initial folder
my $forkNo = 1;#modify in the future
my $pm = Parallel::ForkManager->new("$forkNo");
#load all settings first
my ($system_setting_hr,$dptrain_setting_hr,$npy_setting_hr,$lmp_setting_hr,$scf_setting_hr) = 
&all_settings::setting_hash();
my %system_setting = %{$system_setting_hr};
my %dptrain_setting = %{$dptrain_setting_hr};
my %npy_setting = %{$npy_setting_hr};
my %lmp_setting = %{$lmp_setting_hr};
my %scf_setting = %{$scf_setting_hr};
my $jobtype = $system_setting{jobtype};
my $currentPath = $system_setting{script_dir};
my $mainPath = $system_setting{main_dir};# main path of dpgen folder
my $useFormationEnergy = $system_setting{useFormationEnergy};
#&DFT_SCF(\%system_setting,\%scf_setting,\(0..1));
#+++++++++++
#my $it = 0;
#my @strFoldersThermo = `find $mainPath/DFT_output -maxdepth 2 -mindepth 2 -type d -name "*"`;
#    chomp @strFoldersThermo;
#    my @scfdone;#with "! total energy" in sout file
#    my %strFolders;#scf-done folder information of a structure in different folders (different thermostates by dft scf)
#    for my $folder (@strFoldersThermo){
#        my $temp = `grep "JOB DONE" $folder/*.sout`;#only one sout file
#        if($temp){#with ! totoal energy (scf done)
#            #$folder: ../DFT_output/T2000-P0-R3000-Al-12345/lmp_1500
#            $folder =~ /.+T\d+-P\d+-R\d+-(.+)\/.+/;#structure in initial folder
#            chomp $1;#Al-12345 in this example
#            push @{$strFolders{$1}},$folder;
#            #print "folder: $folder, $1\n";
#        }
#        else{
#            print "#scf of sout file in $folder has problem!!!\n";
#        }
#    } 
##collect all sout and in files for a structure for npy convertion (could no good sout files if all failed)   
#    my @str = keys %strFolders;
#    
#    for my $str (@str){
#        #print "str: $str\n";
#        `mkdir -p  $mainPath/DFT_output/$str`;#collect all dft in and sout files originated from the same initial structure
#        my @temp = @{$strFolders{$str}};
#        for my $id (0..$#temp){
#            my $tempid = sprintf("%02d",$id);
#            `cp $temp[$id]/*.sout $mainPath/DFT_output/$str/$tempid.sout`;#dft output
#            `cp $temp[$id]/*.in $mainPath/DFT_output/$str/$tempid.in`;#dft input
#        };
#    } 
##begin npy convertion     
#    for my $str (@str){#loop over all strucutres 
#        $npy_setting{inistr_dir}  = "$mainPath/initial/$str";
#        $npy_setting{npyout_dir}  = "$mainPath/all_npy/$it/$str";
#        `mkdir -p $mainPath/all_npy/$it/$str`;
#        #print "$str $npy_setting{npyout_dir}\n";    
#        $npy_setting{dftsout_dir}  = "$mainPath/DFT_output/$str";
#        my @BE_all = `cat $npy_setting{inistr_dir}/dpE2expE.dat|grep -v "#"|awk '{print \$3}'`;
#        die "no dpE2expE.dat in $npy_setting{inistr_dir}\n" unless (@BE_all);
#        chomp @BE_all;
#        $npy_setting{dftBE} = $BE_all[0];
#        $npy_setting{expBE} = $BE_all[1];
#        &DFTout2npy_QE(\%system_setting,\%npy_setting);
#    }#str loop
##++++++++++
#die;
#check all QE input file setting
my @ref_QE = `egrep "etot_conv_thr|forc_conv_thr|pseudo_dir|ecutwfc|ecutrho" $currentPath/QE_script.in`;
chomp @ref_QE;
my %QE_keyRef;#make numeric values
my %QE_keyRefOri;#original string format for double precision
#for (@ref_QE){
#    s/^\s+|\s+$//;#remove beginnig and end empty space
#    /(\w+)\s*=\s*(.+)/;
#    chomp($1,$2);
#    my $tmpkey = $1;
#    my $tmpval = $2;
#    if($tmpkey eq "pseudo_dir"){
#        $QE_keyRef{$tmpkey}=$tmpval;
#    }
#    else{
#        unless($tmpval =~/d/){
#            die "*You must use the format of ".
#            "double precision for $tmpkey in $currentPath/QE_script.in".
#            "For a double precision example, 1.600d-04\n";
#        };
#        $tmpval =~/(.*)d([+|-].*)/;
#        $QE_keyRef{$tmpkey}= $1*10**$2;
#        $QE_keyRefOri{$tmpkey}= $tmpval;
#    }
#}
##make type.raw, masses.dat, and elements.dat
my @QE_in = `find $mainPath/initial -type f -name "*.in"|grep -v "scale*"`;#all QE input
chomp @QE_in;
for my $in (@QE_in){
    print "$in\n";
    my $path = `dirname $in`;
    my $filename = `basename $in`;
    $filename =~ s/\..*//g;
    chomp ($path,$filename);
    my $natom = `egrep nat $in`;#check atom number in QE input. atom number <=1 is not allowed
    chomp $natom;
    $natom =~ s/^\s+|\s+$//;#remove beginnig and end empty space
    $natom =~ /(\w+)\s*=\s*(.+)/;
    chomp ($1,$2);
    my $nat = $2;
    if($2 <= 3){
        print"\n***1. Atom number (currently, nat = $2) in $in is not allowed. The nat value should be => 4.\n";
        print"###2. Please modify your current system to have at least 4 atoms and conduct the QE calculation again.\n\n";
        die;    
    }
    #the element id for dpgen and can be used for assigning type id for data files 
    my @typemap = @{$dptrain_setting{type_map}};
    map { s/^\s+|\s+$//g; } @typemap;
    #for lammps type id
    my %ele2id = map { $typemap[$_] => $_ + 1  } 0 .. $#typemap;
    #modify all data files when merging all systems
    my $atom_types = @typemap;

    #get the corresponding element symbols with id sequence from QE input
    my @elem = `grep -v '^[[:space:]]*\$' $in|grep -A $nat "ATOMIC_POSITIONS [(|{]angstrom[)|}]"|grep -v "ATOMIC_POSITIONS [(|{]angstrom[)|}]"|grep -v -- '--'|awk '{print \$1}'`;
    map { s/^\s+|\s+$//g; } @elem; 
    my $elements = join(" ",@elem);
    #print "$in\n";
    #print "$elements\n";
    open(FH, "> $path/elements.dat") or die $!;
    print FH $elements;
    close(FH);

    my @type_raw = map { $ele2id{$elem[$_]} - 1  } 0 .. $#elem;
    my $type_raw = join(" ",@type_raw);
    #print "$type_raw\n";
    open(FH, "> $path/type.raw") or die $!;
    print FH $type_raw;
    close(FH);
   #get masses for data files
    my $mass4data;
    my $masses_dat;
    my $counter = 1;
    for my $e (0..$#typemap) {        
        my $ele = $typemap[$e];        
        my $mass = &elements::eleObj("$ele")->[2];
        $mass4data .= $e+1 . " $mass  \# $ele\n";           
        $masses_dat .= "$mass\n";           
    }
    chomp $mass4data;#move the new line for the last line
    chomp $masses_dat;#move the new line for the last line
    #print "$mass4data\n";
    #print "$masses_dat\n";
    open(FH, "> $path/masses.dat") or die $!;
    print FH $masses_dat;
    close(FH);
    #get cell
    my @lmp_cell = `cat $path/$filename.data|egrep "xlo|ylo|zlo|xy"`;#"[xlo|ylo|zlo|xy]"`;#|grep -v Atoms|grep -v -- '--'`;
    die "No cell information of $path/$filename.data for $in" unless(@lmp_cell);
    map { s/^\s+|\s+$//g; } @lmp_cell;
    unless($lmp_cell[3]){$lmp_cell[3] = "0.0000 0.0000 0.0000 xy xz yz";}
    my $lmp_cell = join("\n",@lmp_cell);
    chomp $lmp_cell;
    #print "\$lmp_cell: $lmp_cell\n end\n";
    #die; 

    #system("cat $in");
    my @lmp_coors = `cat $path/$filename.data|grep -v '^[[:space:]]*\$'|grep -A $nat Atoms|grep -v Atoms|grep -v -- '--'`;
    die "No $path/$filename.data for $in" unless(@lmp_coors);
    map { s/^\s+|\s+$//g; } @lmp_coors; 
    die "data coords number is not equal to elem symbol number in QE input\n"  if(@lmp_coors != @elem) ;
    #need use QE elem symbol to assign new lmp type id
     my $coords4data;
    for my $e (0..$#lmp_coors) {
        my @tempcoords = split (/\s+/,$lmp_coors[$e]);
        map { s/^\s+|\s+$//g; } @tempcoords;
        $tempcoords[1] = $ele2id{$elem[$e]} ;#change type id here!
        my $temp = join(" ",@tempcoords);
        $coords4data .= "$temp\n";      
    }
    chomp $coords4data;
    #print "$coords4data\n";
# modify data file

my $here_doc =<<"END_MESSAGE";
# $in

$nat atoms
$atom_types atom types

$lmp_cell

Masses

$mass4data

Atoms  # atomic

$coords4data
END_MESSAGE

open(FH, "> $path/$filename.data") or die $!;
print FH $here_doc;
close(FH);

    #my @temp = `egrep "etot_conv_thr|forc_conv_thr|pseudo_dir|ecutwfc|ecutrho" $in`;
        #for (@temp){
        #    s/^\s+|\s+$//;#remove beginnig and end empty space
        #    /(\w+)\s*=\s*(.+)/;
        #    chomp($1,$2);
        #    my $tmpkey = $1;
        #    my $tmpval = $2;
        #    #    print "###123, $tmpkey, $tmpval\n";
        #    if($tmpkey ne "pseudo_dir"){
        #         unless($tmpval =~/d/){
        #            die "\n*You must use the format of ".
        #            "double precision for $tmpkey in $in".
        #            "For a double precision example, 1.600d-04\n";
        #          };
        #        $tmpval =~/(.*)d([+|-].*)/;
        #        my $temp = $1*10**$2;
        #        if($QE_keyRef{$tmpkey} != $temp){
        #            #print "123, $tmpkey, $tmpval\n";
        #            #print "\$QE_keyRef{$tmpkey}, $QE_keyRef{$tmpkey}\n \n";
        #            my $temp1 = $QE_keyRefOri{$tmpkey};
        #            my $temp2 = $tmpval;
        #            chomp ($temp1,$temp2);
        #            print "\n###$tmpkey setting: $temp1,$temp2####\n";
        #            print "In $currentPath/QE_script.in and $in\n";
        #            print "AND\n";
        #            print "In $in\n";
        #            print "ARE DIFFERENT!!!!\n";
        #            
        #            print "\n***** You must use the same settings for etot_conv_thr, forc_conv_thr, pseudo_dir, ecutwfc, ecutrho ".
        #            "in each QE input file (also in $currentPath/QE_script.in). Otherwise, your dptrain result could be not good!\n";
        #        ##    die;
        #        }
        #    }
        #    elsif($tmpkey eq "pseudo_dir" and $QE_keyRef{$tmpkey} ne $tmpval){
        #        #print "123, $tmpkey, $tmpval\n";
        #        #print "\$QE_keyRef{$tmpkey}, $QE_keyRef{$tmpkey}\n \n";
        #        print "The setting for $tmpkey is different in ".
        #        "$currentPath/QE_script.in (currently for $QE_keyRef{$tmpkey})\n";
        #        print "and in $in (currently for $tmpval).\n";
        #        print "\n***** You must use the same settings for etot_conv_thr, forc_conv_thr, pseudo_dir, ecutwfc, ecutrho ".
        #        "in each QE input file (also in $currentPath/QE_script.in). Otherwise, your dptrain result could be not good!\n";
        #     ##   die;
        #    }
        #}
}

#if($onlyfinal_dptrain eq "yes") {goto final_dptrain;}
#make all required folders and slurm files
&all_settings::create_required();

#three-dimensional array for all thermostates
my ($iteration_ar,$allIniStr_ar) = &all_settings::all_thermostate();
my @iteration = @{$iteration_ar};
my @allIniStr = @{$allIniStr_ar};

#You may do some debugging here
#die "test\n";
#my $iter = 0;
#my $convergedNo = &DFT_SCF(\%system_setting,\%scf_setting,\@{$iteration[$iter]});#do DFT scf for npy files
#die;
#&matplot(\%system_setting,\%dptrain_setting);
#die;
####starting the initial dp training
#get initial npy files
if($jobtype eq "new"){# a brand new dpgen job. No previous labeled npy files exist
    print "\n\n#***Doing initial npy convertion\n";
    `rm -rf $mainPath/matplot`;
    `rm -rf $mainPath/all_npy`;
    `mkdir -p $mainPath/all_npy`;
    #the following loop also check the required files in the corresponding folder
    for my $str (@allIniStr){
        chomp $str;
        $npy_setting{inistr_dir}  = "$mainPath/initial/$str";
        $npy_setting{npyout_dir}  = "$mainPath/all_npy/initial/$str";
        #print "$str $npy_setting{npyout_dir}\n";    
        $npy_setting{dftsout_dir}  = "$mainPath/initial/$str";
    # check filenames 
        my $dataname =`ls $mainPath/initial/$str/$str.data`;#check data file name
        die "No $str.data in $mainPath/initial/$str\n" unless($dataname);
        my $QEname =`ls $mainPath/initial/$str/$str.in`;#check data file name
        die "No $str.in (QE input) in $mainPath/initial/$str\n" unless($QEname);
        my $QEout =`ls $mainPath/initial/$str/$str.sout`;#check data file name
        die "No $str.sout (QE output) in $mainPath/initial/$str\n" unless($QEout);
        
    #check element symbol
        my $elements =`cat $mainPath/initial/$str/elements.dat|egrep -v "#|^\$"`;#get element types of all atoms
        $elements  =~ s/^\s+|\s+$//;#remove beginnig and end empty space
	    my @elements = split (/\s+/,$elements);#id -> element type
        die "No atoms in the elements.dat for $mainPath/initial/$str\n" unless(@elements);


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
        if($useFormationEnergy eq "yes"){
            my @BE_all = `cat $npy_setting{inistr_dir}/dpE2expE.dat|grep -v "#"|awk '{print \$3}'`;
            die "no dpE2expE.dat in $npy_setting{inistr_dir}\n" unless (@BE_all);
            chomp @BE_all;
            $npy_setting{dftBE} = $BE_all[0];#summation of dft binding energies of all atoms
            $npy_setting{expBE} = $BE_all[1];#summation of exp binding energies of all atoms
            &DFTout2npy_QE(\%system_setting,\%npy_setting);#send settings for getting npy
        }
        else{
            $npy_setting{dftBE} = 0.0;#not used
            $npy_setting{expBE} = 0.0;#not used
            &DFTout2npy_QE(\%system_setting,\%npy_setting);#send settings for getting npy
        }
    }
    die "Only do the npy convertion for data in the initial folder.\n" if($initial_npyOnly eq "yes");
}
elsif($jobtype eq "rerun"){# old npy files exist
    print "\n\n#***Doing jobtype for rerun\n";
    print "The beginning iteration number is $system_setting{begIter}\n";
    die "The beginning iteration number for rerun is 0, incorrect beginning iteration number\n" if ($system_setting{begIter} == 0);
}
elsif($jobtype eq "dpgen_again"){# old npy files exist
    print "\n\n#***Doing jobtype for dpgen_again\n";
    `rm -rf $mainPath/matplot`;   
    `rm -rf $mainPath/all_npy`;
    `mkdir -p $mainPath/all_npy`;
    my @energy_raw = `find $mainPath/all_npy* -type f -name "energy.raw"`;
    chomp @energy_raw;
    for my $en (@energy_raw){
        $en =~ s/^\s+|\s+$//;#remove beginnig and end empty space
        my @temp = `cat $en|egrep -v "#|^\$"`;
        chomp @temp;
        for my $v (@temp){
           die "You need to remove this set of npy files ($en), ",
           "because the energy,$v is positive (unstable for dp train).\n" if($v > 0.0);     
        }
    }
    #print "@energy_raw\n";
    #die;
}
else{
    die "wrong jobtype setting in all_settings.pm\n";
}

# plot files
`rm -rf $mainPath/matplot`;
`mkdir -p $mainPath/matplot`;

#collect all raw data from dp test
`rm -rf $mainPath/matplot_data`;
`mkdir -p $mainPath/matplot_data`;

# training on all npy files in all_npy* folders
print "#***Doing initial deepMD training\n";

my @allnpys = `find $mainPath/all_npy*  -type f -name "*.npy"`;
chomp @allnpys;
my %allnpyfolders;
for (@allnpys){
    my $temp =  `dirname $_`;
    chomp $temp;
    my $temp1 =  `dirname $temp`;
    chomp $temp1;
    #print "$temp1\n";
    $allnpyfolders{$temp1} = 1;
}
my @extraFolders = sort keys %allnpyfolders;

#my @extraFolders = `find $mainPath/all_npy* -maxdepth 2 -mindepth 2 -type d -name "*"`;#all npy files
chomp @extraFolders;
die "no npy files in  $mainPath/all_npy* folders\n" unless(@extraFolders);
#
$dptrain_setting{allnpy_dir} = [@extraFolders];
$system_setting{iter} = "initial dp train";
&dp_train(\%system_setting,\%dptrain_setting);
#check whether all dp train ok
my $trainNo = $system_setting{trainNo};
for (1..$trainNo){
    my $temp = sprintf("%02d",$_);
    chomp $temp;
    #$mainPath/dp_train/graph$temp/
    my $dpcheck = `grep "finished training" $mainPath/dp_train/graph$temp/dp$temp.dpout`;
    die " dp train failed for dp$temp.dpout! at initial training\n" unless($dpcheck);
}

#begin make plots for training results
`cp -R $mainPath/all_npy* $mainPath/matplot`;
print "making plots for checking training results before iteration loop\n";
&matplot(\%system_setting,\%dptrain_setting);

print "\n\n#****Main iteration begins****#\n";
my $begIter = $system_setting{begIter};#assign correct beginning iteration number

for my $iter ($begIter..$#iteration){
    $system_setting{iter} = $iter;
    my $it = "iter_". sprintf("%03d",$iter);#for mkdir
    print "\n#*** DPGEN ITERATION: $iter\n";
# lmp jobs for labeling
    # 1 is ok, 0 is nothing labbelled 
    print "#Doing lmp_label at iteration $iter\n";
    my $labelorNot = &lmp_label(\%system_setting,\%lmp_setting,\@{$iteration[$iter]});#do lmp for labelling
    print "\$labelorNot: $labelorNot at $it (0 for none after lmp labeling)\n";
    next unless($labelorNot);#if nothing labelled, go to next iteration for different thermostate
    sleep(1);
    #do lammps MD for initial training check
    die "Only initial training is done! (\$initial_trainOnly = \"yes\")\n" if($initial_trainOnly eq "yes");
#print "\$initial_trainOnly:$initial_trainOnly\n";
#begin DFT SCF for all labelled structures by lmp
    print "\n#Doing DFT_SCF at iteration $iter\n";
    my $convergedNo = &DFT_SCF(\%system_setting,\%scf_setting,\@{$iteration[$iter]});#do DFT scf for npy files
    print "#final convergedNo after DFT_SCF: $convergedNo\n";    
    next unless($convergedNo);#if nothing labelled, go to next iteration

#convert dftoutput (XX.sout from slurm) to npy
    print "#Doing SCF output to npy files at iteration $iter\n";
    `rm -rf $mainPath/all_npy/$it`;# place all npy files for this iteration
    `mkdir -p $mainPath/all_npy/$it`;
    #structure types with the corresponding thermostate
    my @strFoldersThermo = `find $mainPath/DFT_output -maxdepth 2 -mindepth 2 -type d -name "*"`;
    chomp @strFoldersThermo;
    my @scfdone;#with "! total energy" in sout file
    my %strFolders;#scf-done folder information of a structure in different folders (different thermostates by dft scf)
    for my $folder (@strFoldersThermo){
        my $temp = `grep "JOB DONE" $folder/*.sout`;#only one sout file
        if($temp){#with ! totoal energy (scf done)
            #$folder: ../DFT_output/T2000-P0-R3000-Al-12345/lmp_1500
            $folder =~ /.+T\d+-P\d+-R\d+-(.+)\/.+/;#structure in initial folder
            chomp $1;#Al-12345 in this example
            push @{$strFolders{$1}},$folder;
        }
        else{
            print "#scf of sout file in $folder has problem!!!\n";
        }
    } 
#collect all sout and in files for a structure for npy convertion (could no good sout files if all failed)   
    my @str = keys %strFolders;
    
    for my $str (@str){
        `mkdir -p  $mainPath/DFT_output/$str`;#collect all dft in and sout files originated from the same initial structure
        my @temp = @{$strFolders{$str}};
        for my $id (0..$#temp){
            my $tempid = sprintf("%02d",$id);
            `cp $temp[$id]/*.sout $mainPath/DFT_output/$str/$tempid.sout`;#dft output
            `cp $temp[$id]/*.in $mainPath/DFT_output/$str/$tempid.in`;#dft input
        };
    } 
#begin npy convertion     
    for my $str (@str){#loop over all strucutres 
        $npy_setting{inistr_dir}  = "$mainPath/initial/$str";
        $npy_setting{npyout_dir}  = "$mainPath/all_npy/$it/$str";
        `mkdir -p $mainPath/all_npy/$it/$str`;
        #print "$str $npy_setting{npyout_dir}\n";    
        $npy_setting{dftsout_dir}  = "$mainPath/DFT_output/$str";
        my @BE_all = `cat $npy_setting{inistr_dir}/dpE2expE.dat|grep -v "#"|awk '{print \$3}'`;
        die "no dpE2expE.dat in $npy_setting{inistr_dir}\n" unless (@BE_all);
        chomp @BE_all;
        $npy_setting{dftBE} = $BE_all[0];
        $npy_setting{expBE} = $BE_all[1];
        &DFTout2npy_QE(\%system_setting,\%npy_setting);
    }#str loop
# training on the all npy files (all_npy*)->all_npy00,all_npy01 from previous dpgen process
    my @allnpys = `find $mainPath/all_npy*  -type f -name "*.npy"`;
    chomp @allnpys;
    my %allnpyfolders;
    for (@allnpys){
        my $temp =  `dirname $_`;
        chomp $temp;
        my $temp1 =  `dirname $temp`;
        chomp $temp1;
        #print "$temp1\n";
        $allnpyfolders{$temp1} = 1;
    }
    my @extraFolders = sort keys %allnpyfolders;

    #housekeeping 
    my @tempfolders = `find $mainPath/all_npy* -maxdepth 2 -mindepth 2 -type d -name "*"`;
    chomp @tempfolders;
    for (@tempfolders){
        unless(exists $allnpyfolders{$_}){
            print "no npy files in $_\n";
            `rm -rf $_`;
        }
    }
    #my @extraFolders = `find $mainPath/all_npy* -maxdepth 2 -mindepth 2 -type d -name "*"`;
    chomp @extraFolders;
    print "#Doing dp train at iteration $iter\n\n";
    $dptrain_setting{allnpy_dir} = [@extraFolders];
    &dp_train(\%system_setting,\%dptrain_setting);
    for (1..$trainNo){
        my $temp = sprintf("%02d",$_);
        chomp $temp;
        #$mainPath/dp_train/graph$temp/
        my $dpcheck = `grep "finished training" $mainPath/dp_train/graph$temp/dp$temp.dpout`;
        die " dp train failed for dp$temp.dpout at iteration $iter\n" unless($dpcheck);
    }

    print "making plots for checking training results for iteration $iter\n";
    #`rm -rf $mainPath/matplot/all_npy`;
    `cp -R $mainPath/all_npy $mainPath/matplot`;
    &matplot(\%system_setting,\%dptrain_setting);
}#iteration loop

#final_dptrain:
#if($iter == $#iteration){
#        print "****doing the last training.\n";
#        print "original training step number: $dptrain_setting{trainstep}\n";
#        $dptrain_setting{trainstep} = $dptrain_setting{trainstep} * 10;
#        print "step number for the last training: $dptrain_setting{trainstep}\n";
#}
    
print "\n#****All Done!\n";
#@extraFolders = `find $mainPath/all_npy -maxdepth 2 -mindepth 2 -type d -name "*"`;
#chomp @extraFolders;
#$dptrain_setting{allnpy_dir} = [@extraFolders];
#&final_dptrain(\%system_setting,\%dptrain_setting);
#
#print "#End of final dp train\n";
#print "#dpgen job done!!!\n";



