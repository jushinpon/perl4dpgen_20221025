=b
1.You need to check all slurm sh files (slurm_dp, slurm_dft, slurm_lmp) for using current path and ld_path settings
2. QE path
3. partition
set all dpgen parameters for all sub processes

=cut
package all_settings; 

use strict;
use warnings;
use Cwd;
use POSIX;

my $currentPath = getcwd();# dir for all scripts
chdir("..");
my $mainPath = getcwd();# main path of Perl4dpgen dir
chdir("$currentPath");
my $NVT4str = "no";
my @allNVTstru = ("");#("bcc_bulk");#,"fcc_bulk","hcp_bulk");for surface
# should have the same names as in the initial folder
my $NPT4str = "yes";
my @allNPTstru = ("md-rocksalt-Ag05Ge05Mn05Sb35Te50","md-rocksalt-Ag05Ge05Mn35Sb05Te50","md-rocksalt-Ag06Ge06Mn34Sb06Te50","md-rocksalt-Ag06Ge34Mn06Sb06Te50","md-rocksalt-Ag08Ge08Mn08Sb29Te50","md-rocksalt-Ag08Ge08Mn29Sb08Te50","md-rocksalt-Ag08Ge29Mn08Sb08Te50","md-rocksalt-Ag09Ge09Mn09Sb25Te50","md-rocksalt-Ag09Ge09Mn25Sb09Te50","md-rocksalt-Ag09Ge25Mn09Sb09Te50","md-rocksalt-Ag10Ge10Mn10Sb20Te50","md-rocksalt-Ag13Ge13Mn13Sb13Te50","md-rocksalt-Ag13Ge13Mn13Sb13Te50_3d-03","md-rocksalt-Ag20Ge10Mn10Sb10Te50","md-rocksalt-Ag25Ge09Mn09Sb09Te50","md-rocksalt-Ag32Ge07Mn07Sb07Te50","md-rocksalt-Ag34Ge06Mn06Sb06Te50","md-rocksalt-Ag35Ge05Mn05Sb05Te50","Opt-rocksalt-Ag20Ge10Mn10Sb10Te50");
my @allPress = (0.0);#unit:bar,the pressures your want to use for labelling
my @allStep = (3000);#time step number, should be larger than 500 (default output_freq)
#prefixes of data and QE in files should be the same as the foldername !!!!
my @allIniStr =  ("md-rocksalt-Ag05Ge05Mn05Sb35Te50","md-rocksalt-Ag05Ge05Mn35Sb05Te50","md-rocksalt-Ag06Ge06Mn34Sb06Te50","md-rocksalt-Ag06Ge34Mn06Sb06Te50","md-rocksalt-Ag08Ge08Mn08Sb29Te50","md-rocksalt-Ag08Ge08Mn29Sb08Te50","md-rocksalt-Ag08Ge29Mn08Sb08Te50","md-rocksalt-Ag09Ge09Mn09Sb25Te50","md-rocksalt-Ag09Ge09Mn25Sb09Te50","md-rocksalt-Ag09Ge25Mn09Sb09Te50","md-rocksalt-Ag10Ge10Mn10Sb20Te50","md-rocksalt-Ag13Ge13Mn13Sb13Te50","md-rocksalt-Ag13Ge13Mn13Sb13Te50_3d-03","md-rocksalt-Ag20Ge10Mn10Sb10Te50","md-rocksalt-Ag25Ge09Mn09Sb09Te50","md-rocksalt-Ag32Ge07Mn07Sb07Te50","md-rocksalt-Ag34Ge06Mn06Sb06Te50","md-rocksalt-Ag35Ge05Mn05Sb05Te50","Opt-rocksalt-Ag20Ge10Mn10Sb10Te50");#for the fisrt dp train,should include all structures for labeling
#my @allIniStr =  ("N2","N2SCF","N25","N154","N568584","N570747","N672233","N754514","N999498","N1080711","N1176403","B160","B161","B22046","B541848","B570316","B570602","B632401","B1193675","B1198656","B1202723","B1228790","BN344","BN534","BN984","BN1599","BN1639","BN2653","BN7991");#for the fisrt dp train,should include all structures for labeling
#"bcc_bulk",
my %system_setting;
#$system_setting{QE_pot} = "/opt/QEpot/SSSP_precision.json";#"new";#check readme
$system_setting{useFormationEnergy} = "no";#if "yes", you need to prepare dpE2expE.dat in each folder under ./initial
$system_setting{QE_pot_json} = "/opt/QEpot/SSSP_efficiency.json";#"new";#check readme
$system_setting{jobtype} = "new";#"new";#check readme
$system_setting{begIter} = 0;#0 for $system_setting{jobtype} = "new" or "dpgen_again"
#for rerun, check readme
$system_setting{debug} = "yes";#no for a brand new run
$system_setting{dft_exe} = "/opt/QEGCC_MPICH4.0.3-cp/bin/";#not workable, you need to modify this in slurm batch and partition
$system_setting{lmp_exe} = "/opt/lammps-mpich-4.0.3/lmpdeepmd_20230322";#not workable, you need to modify this in slurm batch and partition
$system_setting{partition} = "debug";#for slurm sbatch file
$system_setting{main_dir} = $mainPath;
$system_setting{script_dir} = $currentPath;
#$system_setting{mpi_dir} = #modify in the future
$system_setting{trainNo} = 1;# training number at a time
$system_setting{iter} = 0;
$system_setting{T_hi} = 500;#the higest temperature for lammps
$system_setting{T_lo} = 300;#the lowest temperature for lammps
$system_setting{T_incNo} = 2;#total increment number from T_lo to T_hi,
#the total temperature number considered is the above value + 1;
$system_setting{T_No} = 2;#how many temperatures you want to consider within a temperature range, at lease 2

my %dptrain_setting; 
$dptrain_setting{type_map} = [("Ag","Ge","Mn","Sb","Te")];# json template file
$dptrain_setting{json_script} = "$currentPath/template.json";# json template file
$dptrain_setting{json_outdir} = "$mainPath/dp_train";
$dptrain_setting{working_dir} = "$mainPath/dp_train";
$dptrain_setting{trainstep} = 200000;#you may set a smaller train step for the first several dpgen processes
$dptrain_setting{compresstrainstep} = 80000;
$dptrain_setting{final_trainstep} = 200000;
$dptrain_setting{final_compresstrainstep} = 400000;
#lr(t) = start_lr * decay_rate ^ ( t / decay_steps ),default decay_rate:0.95
$dptrain_setting{start_lr} = 0.005;
my $t1 = log(3.0e-08/$dptrain_setting{start_lr});
my $t2 = log(0.95)*$dptrain_setting{trainstep};
my $dcstep = floor($t2/$t1);
$dptrain_setting{decay_steps} = $dcstep;
$dptrain_setting{final_decay_steps} = 5000;
$dptrain_setting{disp_freq} = 1000;
$dptrain_setting{save_freq} = 1000;
my $temp =$dptrain_setting{start_lr} * 0.95**( $dptrain_setting{trainstep}/$dptrain_setting{decay_steps} );
$dptrain_setting{start_lr4compress} = $temp;
$dptrain_setting{rcut} = 6.00000000000001;
$dptrain_setting{rcut_smth} = 5.80000000001;
$dptrain_setting{descriptor_type} = "se_a";
$dptrain_setting{save_ckpt} = "model.ckpt";
$dptrain_setting{save_ckpt4compress} = "model_compress.ckpt";
$dptrain_setting{disp_file} = "lcurve.out";
$dptrain_setting{disp_file4compress} = "lcurve_compress.out";

#export OMP_NUM_THREADS=6
#export TF_INTRA_OP_PARALLELISM_THREADS=3
#export TF_INTER_OP_PARALLELISM_THREADS=2
my %npy_setting;# most by dynamical setting

#lmp setting
my %lmp_setting;#from main

$lmp_setting{masses}  = [(107.8682,54.938044,72.63,121.76,127.6)];#masses for lmp script
$lmp_setting{ori_lmp_script}  = "$mainPath/scripts/lmp_script.in";#lmp script template, the same folder as this perl
$lmp_setting{ori_slurm_script}  = "$mainPath/scripts/slurm_lmp.sh";#slurm script template
$lmp_setting{lmp_working_dir}  = "$mainPath/lmp_label";#folder for all lmp jobs
$lmp_setting{lmp_graph_dir}  = "$mainPath/dp_train";#folder for all lmp jobs
$lmp_setting{maxlabel}  = 1;#max number for labeling data files
$lmp_setting{upper_bound}  = 0.2;#if dft has convergence problem, decrease it.
$lmp_setting{lower_bound}  = 0.05;#lower bound for labelling. smaller value,0.01, for fewer initial structures
$lmp_setting{out_freq}  = 100;#data file and deviation output freq
$lmp_setting{ts}  = 0.001;#timestep size for unit metal

my %scf_setting;


sub setting_hash {# return hash of a setting
    #my @settings = (%system_setting,%dptrain_setting,%npy_setting);
    return (\%system_setting,\%dptrain_setting,\%npy_setting,\%lmp_setting,\%scf_setting);
}

sub create_required{

#make all required folders
#`mkdir -p ../lmp_label`;# for all lmp jobs
#`mkdir -p ../all_npy`;# all npy files
#`mkdir -p ../DFT_output`;# all sout for next npy convertion
#`mkdir -p ../dp_train`;# training for graph files
#slurm files for dp train.
my $forkNo = 100;#although we don't have so many cores, only for submitting jobs into slurm
my $pm = Parallel::ForkManager->new("$forkNo");
    my $trainNo = $system_setting{trainNo};
    my $json_outdir = $dptrain_setting{json_outdir};
#make folders and files will not change during the dpgen process    
    for (1..$trainNo){
        $pm->start and next;
        my $temp = sprintf("%02d",$_);
        #folders for dp train
        `mkdir -p $json_outdir/graph$temp`;
        my $json_script = "$json_outdir/slurm_dp$temp.sh";#absolute path for json script
        #slurm for dp train (you must set several lines for anchor keywords)
        `cp ./slurm_dp.sh $json_script`;    
   #     #modify job name
        `sed -i '/#SBATCH.*--job-name/d' $json_script`;
	    `sed -i '/#sed_anchor01/a #SBATCH --job-name=dp$temp' $json_script`;
   #     #modify output file name
	    `sed -i '/#SBATCH.*--output/d' $json_outdir/slurm_dp$temp.sh`;
	    `sed -i '/#sed_anchor01/a #SBATCH --output=dp$temp.dpout' $json_outdir/slurm_dp$temp.sh`;
   #     #modify json file name and path
	    `sed -i '/dp train .*/d' $json_outdir/slurm_dp$temp.sh`;
	    `sed -i '/#sed_anchor02/a dp train $json_outdir/graph$temp.json' $json_outdir/slurm_dp$temp.sh`;
	    `sed -i '/dp freeze .*/d' $json_outdir/slurm_dp$temp.sh`;
	    `sed -i '/#sed_anchor03/a dp freeze -o graph$temp.pb' $json_outdir/slurm_dp$temp.sh`;
       # `sed -i '/dp compress .*/d' $json_outdir/slurm_dp$temp.sh`;
	   # `sed -i '/#sed_anchor04/a dp compress -i graph$temp.pb -o graph-compress$temp.pb' $json_outdir/slurm_dp$temp.sh`;
       # `sed -i '/init-frz-model .*/d' $json_outdir/slurm_dp$temp.sh`;
	   # `sed -i '/#sed_anchor05/a dp train $json_outdir/graph$temp-compress.json --init-frz-model graph-compress$temp.pb' $json_outdir/slurm_dp$temp.sh`;
  $pm-> finish;  
    }
$pm->wait_all_children;   
}#sub

sub all_thermostate{

my @allTemp;#temperatures for setting upper and lower bounds for each range( 1 + T_incNo number for T_incNo ranges)
my $temp_inc = ($system_setting{T_hi} - $system_setting{T_lo})/$system_setting{T_incNo};#temp increment
$allTemp[0] = $system_setting{T_lo};# the lowest temperature as a base temperature
for (1..$system_setting{T_incNo}){$allTemp[$_] = $allTemp[0] + int($temp_inc * $_);}
my @Tgroup;#for lmp to conduct with this temperature number at the same dpgen iteration
my $g_counter = 0;
for my $T_bound (0.. $#allTemp - 1){
    my $localTinc = ($allTemp[$T_bound + 1] - $allTemp[$T_bound])/$system_setting{T_No};
    my $end = $system_setting{T_No} -1;
    if($T_bound == $#allTemp - 1){$end = $system_setting{T_No}}# for the higest temperature
    for my $t (0..$end){
        my $temp1 = $allTemp[$T_bound] + $t * $localTinc;
        my $temp = int($temp1);
        push @{$Tgroup[$T_bound]},$temp;
    }    
}

my @iteration;#three-dimensional array
#       @{$iteration[0]} = (1 or 0,[temperatures],[pressures],step number,[structures])
my $iter_counter = 0;
if($NPT4str  eq "yes"){ # iteration for NPT lmp 
    for my $Tg (@Tgroup){
        for my $st (@allStep){
            for my $str (@allNPTstru){
                for my $t (@{$Tg}){
                    for my $p (@allPress){
                       print "*iteration for NPT: $iter_counter, temperature: $t K, press: $p bars, step No: $st, structure: $str\n";
                       push @{$iteration[$iter_counter]},[1,$t,$p,$st,$str];# 1 for npt, 0 for nvt
                    }#pressure loop
                }#all temperatures of a temperature group
           }#all structures for NPT MD
            $iter_counter++
        } #all lmp run steps (the same thermal state for different run step lengths and different iterations)
    } # all temperature group (each group includes sverval temperatures at a dpgen iteration)      
} # if 

if ($NVT4str  eq "yes"){ #  iteration for NVT lmp, for surface system only 
    for my $Tg (@Tgroup){
        for my $st (@allStep){
            for my $str (@allNVTstru){
                for my $t (@{$Tg}){
                    print "#iteration for NVT: $iter_counter, temperature: $t K, step No:$st, structure: $str\n";
                    push @{$iteration[$iter_counter]},[0,$t,0.0,$st,$str];#pressure:0.0 not used in lmp script.
                 }#temperarures of a temperature group
            }#structures for nvt lmp
            $iter_counter++
        }#step number of nvt lmp
    }#temperature groups
}#if
return (\@iteration,\@allIniStr);
}#sub

1;