=b
conduct lammps and then label data files within the deviation criterions. 
=cut
use warnings;
use strict;
use JSON::PP;
use Data::Dumper;
use Cwd;
use POSIX;
use Parallel::ForkManager;

sub lmp_label{

my ($ss_hr,$ls_hr,$iter_ar) = @_;
my $forkNo = 100;#although we don't have so many cores, only for submitting jobs into slurm
my $pm = Parallel::ForkManager->new("$forkNo");
my $mainPath = $ss_hr->{main_dir};# main path of dpgen folder
my $currentPath = $ss_hr->{script_dir};# current path 
my $debug = $ss_hr->{debug};
my $iter = "iter". sprintf("%03d",$ss_hr->{iter});
my $trainNo = $ss_hr->{trainNo};#graph file number
my $out_freq = $ls_hr->{out_freq};#graph deviation output every this step
my $maxlabel = $ls_hr->{maxlabel};# max number for labelling of a thermostate
#upper and lower bounds for labelling
my $label_lower = $ls_hr->{lower_bound};
my $label_upper = $ls_hr->{upper_bound};

my @thermostate = @{$iter_ar};#information of all lmp  at an iteration
`rm -rf $ls_hr->{lmp_working_dir}/**`;#remove old folders first
my $graph_dir =$ls_hr->{lmp_graph_dir};#parent dir
my $lmp_tmp = $ls_hr->{ori_lmp_script};#lmp script template, the same folder as this perl
print "#The following thermal conditions are considered for lmp label at $iter:\n";
for my $case (0..$#thermostate){# loop over all cases in an iteration
	$pm->start and next;#submit all jobs of the same iteration at a time
 
    my $seed  = ceil(1234567 * (rand() + $case*rand()));
    my $ensemble = ${$thermostate[$case]}[0];
    my $boundary;
	if($ensemble == 1){#npt
        $boundary  = "p p p";
    }
    else{#nvt, mainly for surface, need modify it in the future
        $boundary  = "p p p";
    }
# the following are further information for this iteration
    my $T = ${$thermostate[$case]}[1];
    my $P = ${$thermostate[$case]}[2];
    my $run_step = ${$thermostate[$case]}[3];
    my $str = ${$thermostate[$case]}[4];
    print "#T: $T, P: $P, run_step:$run_step for structure: $str\n";

    my $read_data = `ls $mainPath/initial/$str/*.data`;
    chomp $read_data;
    my @tempMass = `cat $mainPath/initial/$str/masses.dat|grep -v "#"`;
    chomp @tempMass;
    $ls_hr->{masses} = [@tempMass];
	chomp ($T,$P,$run_step,$str);
	my $job_folder = "T$T-P$P-R$run_step-$str";
	my $lmp_outdir = "$ls_hr->{lmp_working_dir}/$job_folder";#folder with lmp script and working folder
	`mkdir -p $lmp_outdir`;
	`rm -f $lmp_outdir/*.*`;# rm old data
	`rm -rf $lmp_outdir/lmp_output`;# rm old lmp data file output folder
	my $lmp_outscript = "$lmp_outdir/lmp.in";#lmp script 
	`cp $ls_hr->{ori_lmp_script} $lmp_outscript`;
	my $slurm_outscript = "$lmp_outdir/slurm_lmp.sh";#lmp slurm script

#modify lmp script for each case

    my $rand = ceil(1234567 * (rand() + $case*rand()));
	chomp $rand;
	`sed -i 's:variable seed_temp.*:variable seed_temp equal $rand:' $lmp_outscript`;
    `sed -i "s/boundary .*/boundary $boundary/" $lmp_outscript`;
    `sed -i "s/variable run_step .*/variable run_step equal $run_step/" $lmp_outscript`;
    `sed -i "s/variable out_freq .*/variable out_freq equal $out_freq/" $lmp_outscript`;
    `sed -i "s/variable currentT .*/variable currentT equal $T/" $lmp_outscript`;
    `sed -i "s/variable currentP .*/variable currentP equal $P/" $lmp_outscript`;
    `sed -i "s/variable ensemble .*/variable ensemble equal $ensemble/" $lmp_outscript`;
    `sed -i "s/variable ts .*/variable ts equal $ls_hr->{ts}/" $lmp_outscript`;
    `sed -i "s/variable seed .*/variable seed equal $seed/" $lmp_outscript`;
    `sed -i "s+read_data .*+read_data $read_data+" $lmp_outscript`;
    #modify mass
    `sed -i '/mass .*/d' $lmp_outscript`;
    my $mass_counter = 0;
    for (@{$ls_hr->{masses}} ){
    	chomp;
    	$mass_counter++;
        `sed -i '/#mass_anchor/a mass $mass_counter $_' $lmp_outscript`;
    }
    # make pair_stlye graph paths
    my @allgraph;
    for (1..$trainNo){
    	my $temp = sprintf("%02d",$_);
        #my $graph_path = "$mainPath/dp_train/graph$temp/graph-compress$temp.pb";
        my $graph_path = "$mainPath/dp_train/graph$temp/graph$temp.pb";
    	push @allgraph, $graph_path;
    }
    my $allgraph = join (" ",@allgraph);
    $allgraph = $allgraph . " out_file md.out out_freq \${out_freq}" ;

    `sed -i "/pair_style deepmd/d" $lmp_outscript`;
    `sed -i '/#pair_style_anchor/a pair_style deepmd $allgraph' $lmp_outscript`;

#modify slurm_lmp.sh
    `cp $ls_hr->{ori_slurm_script} $slurm_outscript`;
    # #modify job name
    `sed -i '/#SBATCH.*--job-name/d' $slurm_outscript`;
    `sed -i '/#sed_anchor01/a #SBATCH --job-name=$job_folder' $slurm_outscript`;
    #modify output file name
    `sed -i '/#SBATCH.*--output/d' $slurm_outscript`;
    `sed -i '/#sed_anchor01/a #SBATCH --output=$job_folder.lmpout' $slurm_outscript`;
    # #modify script name
    `sed -i '/lmp .*/d' $slurm_outscript`;
    `sed -i '/#mpiexec_anchor/a mpiexec lmp -in lmp.in' $slurm_outscript`;

    chdir("$lmp_outdir");
    system("sbatch ./slurm_lmp.sh");
    chdir("$currentPath");
$pm-> finish;
}# loop over all cases of an iteration
$pm->wait_all_children;# wait for all cases of the same iteration

### check whether all lmp processes are done
my @lmpFolders = `find $mainPath/lmp_label -maxdepth 1 -mindepth 1 -type d -name "*"`;
chomp @lmpFolders;
my $lmpNo = @lmpFolders; # total lmp jobs for this iteration
print "\n#Beginning lmp label while loop at $iter\n\n";
my $whileCounter = 0;
my $Counter = 0;
my $elapsed;
while ($whileCounter <= 5000 and $Counter != $lmpNo ){
	sleep(60);
    $whileCounter += 1;
	$Counter = 0;
    $elapsed = 60.0 * $whileCounter;
 if($debug eq "yes"){
    my $mod = $whileCounter % 5;#every 5 min
    if($mod == 0){#every 5 min
	    for (@lmpFolders){	
	    		if( -e "$_/lmp_done.txt"){
	    			$Counter += 1;
                    print "lmp job in $_ is Done!!!\n";
	    		}
	    		else{
	    			print "lmp job in $_ hasn't Done\n";
	    		}				 
	    }    
        my $min = $elapsed/(60.);
	    print "\n****Doing while loop times for lmp: $whileCounter at $iter\n";
	    print "****Elapsed times: $min min.\n";
	    print "Current number with lmp jobs done: $Counter from $lmpNo jobs\n\n";
    }
    else{#check every min
        for (@lmpFolders){	
	    	if( -e "$_/lmp_done.txt"){
	    		$Counter += 1;                   
	    	}
	    }
    }
 }#if for debug
}#while loop
my $min = $elapsed/(60.);
print "****Elapsed times for all lmp jobs done: $min min.\n\n";

### do labeling
my %label;# key: folder name, value: array to keep labelled cfg filenames
for my $f (@lmpFolders){#loop over all lmp folders with different thermostate
    #if possible, you need to check the format of md.out first
    #$label{$f} = "";# assign initial value for if
    #       step         max_devi_v         min_devi_v         avg_devi_v         max_devi_f         min_devi_f         avg_devi_f
    #       0       4.993334e+00       6.193439e-10       2.882903e+00       2.566617e-08       8.129782e-09       1.717670e-08
    my @mdout = `cat $f/md.out | grep -v step`;#remove header
    chomp @mdout;
    my $counter = 0;
    for my $dev (@mdout){
       $dev =~ s/^\s+|\s+$//;
       #print "\$dev:$dev\n";
       my @temp = split /\s+/, $dev;
       if($temp[-3] <=  $label_upper and $temp[-3] >=  $label_lower){
           push @{$label{$f}},$temp[0];           
           last if (++$counter == $maxlabel);
           #print "$temp[0], $temp[-3],$label{$f},@{$label{$f}}*\n";
       }
    }
    if($label{$f}){#within the labelling criterion
        `mkdir -p $f/labelled`;
        `rm -f $f/labelled/*`;
        for my $id (@{$label{$f}}){`cp $f/lmp_output/lmp_$id.cfg $f/labelled/lmp_$id.cfg`}
    }
    else {
        print "***no labelled structures in $f at iteration $ss_hr->{iter}\n";
    }
}
my @labelled_dir = `find $mainPath/lmp_label -maxdepth 2 -mindepth 2 -type d -name "labelled"`;
chomp @labelled_dir;
if(@labelled_dir){#something has been labelled!
    return 1;
}
else{#nothing was labelled
    return 0;
}
$elapsed = $elapsed/60.;
print "#End of lmp label while loop after $elapsed min at $iter\n\n";

}# end sub
1;