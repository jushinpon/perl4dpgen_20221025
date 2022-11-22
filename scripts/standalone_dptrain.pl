=b
This script help you to do the standalone dptrain using all npy data under a dir.
nohup perl standalone_dptrain.pl > ../standalone.log & 

For your own system, you need to check the following:
1.You need to check your deepmd-kit path (dp train)  and the sbatch file for slurm job submission
2.$dptrain_setting{npy_dir}

=cut
use warnings;
use strict;
use JSON::PP;
use Data::Dumper;
use Cwd;
use POSIX;
use lib '.';#assign pm dir for current dir

#you may change this string by standalone_dptrain01 to keep old standalone trainning data 
my $ref_dir = "standalone_dptrain";#main standalone dir under dpgen

my $currentPath = getcwd();# dir for all scripts
chdir("..");
my $mainPath = getcwd();# main path of Perl4dpgen dir
chdir("$currentPath");

my %dptrain_setting; 
$dptrain_setting{type_map} = [("Ag")];# json template file
$dptrain_setting{valid_ratio} = 0.2;# the validation ratio for all setXX folders,0.2 means 20 % of all set folders
$dptrain_setting{json_script} = "$currentPath/template.json";# json template file
$dptrain_setting{work_dir} = "$mainPath/$ref_dir";#main dir for standalone dp train
$dptrain_setting{npy_dir} = "$mainPath/all_npy*";#you may use your dir, under which all npy files are included.
$dptrain_setting{trainstep} = 200000;#you may set a smaller train step for the first several dpgen processes
$dptrain_setting{start_lr} = 0.001;
my $t1 = log(3.0e-08/$dptrain_setting{start_lr});
my $t2 = log(0.95)*$dptrain_setting{trainstep};
my $dcstep = floor($t2/$t1);
$dptrain_setting{decay_steps} = $dcstep;
$dptrain_setting{disp_freq} = 1000;
$dptrain_setting{save_freq} = 1000;
$dptrain_setting{rcut} = 8.000000000001;
$dptrain_setting{rcut_smth} = 2.00000001;
$dptrain_setting{descriptor_type} = "se_a";
$dptrain_setting{save_ckpt} = "model.ckpt";
$dptrain_setting{disp_file} = "lcurve.out";
my $dps_hr = \%dptrain_setting;

#house keeping first
`rm -rf $dptrain_setting{work_dir}`;
`mkdir -p $dptrain_setting{work_dir}`;

# training on all npy files in all_npy* folders
my @temp = `find $dps_hr->{npy_dir}  -type d -name "set.*"`;#all npy files
die "no npy files in $dps_hr->{npy_dir} folders\n" unless(@temp);
chomp  @temp;
my @allnpy; # dirs with all set.XXX folders
for (0..$#temp){
    my $temp = `dirname $temp[$_]`;
    chomp $temp;
    $allnpy[$_] = $temp;#remove the last set.XX
   # print "$allnpy[$_]\n";
}

my @allnpy4train;
my @allnpy4valid;

chomp @allnpy;
my $allnpyNo = @allnpy;

#keep the information of training and validation data
`rm -f ../standalone_dptrain/train_dir.txt`; 
`rm -f ../standalone_dptrain/valid_dir.txt`; 
`touch ../standalone_dptrain/valid_dir.txt`; 
`touch ../standalone_dptrain/valid_dir.txt`;

for (@allnpy){
    chomp;
    if(rand() >= $dptrain_setting{valid_ratio}){
        push @allnpy4train, $_;#npy for training
        `echo $_ >> ../standalone_dptrain/train_dir.txt`;
    }
    else{
        push @allnpy4valid, $_;#npy for validation
        `echo $_ >> ../standalone_dptrain/valid_dir.txt`;
    }

}

die "No trainning npy files\n" unless(@allnpy4train);
die "No validation npy files. totoal npy files is $allnpyNo",
    " and the pick ratio for validation is $dptrain_setting{valid_ratio}\n",
    unless(@allnpy4valid);
#
#print "@allnpy4train\n";
#die; 
my @type_map = @{$dps_hr->{type_map}};
my $working_dir = $dps_hr->{working_dir};#training folder
my $json_script = $dps_hr->{json_script};#json template
my $work_dir = $dps_hr->{work_dir};#modified json output dir
#### modify json file for dpmd-kit, need to be done in main script
my $json;
{
    local $/ = undef;
    open my $fh, '<', "$json_script" or die "no template.json in scripts path $json_script\n";
    $json = <$fh>;
    close $fh;
}
my $decoded = decode_json($json);
##modify set folders' parent path
$decoded->{training}->{training_data}->{systems} = [@allnpy4train];#clean it first
#use the same for labeling training
$decoded->{training}->{validation_data}->{systems} = [@allnpy4valid];#clean it first
$decoded->{model}->{type_map} = [@type_map];#clean it first
###
my $trainstep = $dps_hr->{trainstep};
my $seed1 = ceil(12345 * rand() );
chomp $seed1;
$decoded->{model}->{descriptor}->{seed} = $seed1;
my $seed2 = ceil(12345 * rand() );
chomp $seed2;
$decoded->{model}->{fitting_net}->{seed} = $seed2;
my $seed3 = ceil(12345 * rand() );
chomp $seed3;
$decoded->{training}->{seed} = $seed3;
$decoded->{training}->{numb_steps} = $trainstep;    
$decoded->{training}->{save_ckpt} = $dps_hr->{save_ckpt};    
$decoded->{training}->{disp_file} = $dps_hr->{disp_file};    
$decoded->{training}->{save_freq} = $dps_hr->{save_freq};    
$decoded->{training}->{disp_freq} = $dps_hr->{disp_freq};    
$decoded->{learning_rate}->{start_lr} = $dps_hr->{start_lr};    
$decoded->{learning_rate}->{decay_steps} = $dps_hr->{decay_steps};    
$decoded->{model}->{descriptor}->{rcut} = $dps_hr->{rcut};    
$decoded->{model}->{descriptor}->{rcut_smth} = $dps_hr->{rcut_smth};    
$decoded->{model}->{descriptor}->{type} = $dps_hr->{descriptor_type};    
{
    local $| = 1;
    open my $fh, '>', "$work_dir/standalone.json";
    print $fh JSON::PP->new->pretty->encode($decoded);#encode_json($decoded);
    close $fh;
}

#create sbatch
my $sbatch_outdir = $dptrain_setting{work_dir};#the same as json output dir
#folders for dp train
`rm -rf $sbatch_outdir/dptrain_output`;
`mkdir -p $sbatch_outdir/dptrain_output`;

my $sbatch_script = "$sbatch_outdir/slurm_dp.sh";#absolute path for json script
#slurm for dp train (you must set several lines for anchor keywords)
`cp ./slurm_dp.sh $sbatch_script`;    
#modify job name
`sed -i '/#SBATCH.*--job-name/d' $sbatch_script`;
`sed -i '/#sed_anchor01/a #SBATCH --job-name=standalone_dptrain' $sbatch_script`;
#modify output file name
`sed -i '/#SBATCH.*--output/d' $sbatch_script`;
`sed -i '/#sed_anchor01/a #SBATCH --output=standalone_dptrain.dpout' $sbatch_script`;
#modify json file name and path
`sed -i '/dp train .*/d' $sbatch_script`;
`sed -i '/#sed_anchor02/a dp train $work_dir/standalone.json' $sbatch_script`;
`sed -i '/dp freeze .*/d' $sbatch_script`;
`sed -i '/#sed_anchor03/a dp freeze -o graph_standalone.pb' $sbatch_script`;

#compress in the future
      # `sed -i '/dp compress .*/d' $work_dir/slurm_dp$temp.sh`;
   # `sed -i '/#sed_anchor04/a dp compress -i graph$temp.pb -o graph-compress$temp.pb' $work_dir/slurm_dp$temp.sh`;
      # `sed -i '/init-frz-model .*/d' $work_dir/slurm_dp$temp.sh`;
   # `sed -i '/#sed_anchor05/a dp train $work_dir/graph$temp-compress.json --init-frz-model graph-compress$temp.pb' $work_dir/slurm_dp$temp.sh`;
#
chdir("$sbatch_outdir/dptrain_output");
system("rm -rf *");
system("sbatch ../slurm_dp.sh");
#slurm
chdir("$currentPath");
my $debug = "yes";
### check whether all dp train processes are done
print "\n\n#Beginning dp train while loop for standalone script.\n";
my $whileCounter = 0;
my $Counter = 0;
my $elapsed;
while ($whileCounter <= 5000 and $Counter != 1){
	sleep(60);
    $whileCounter += 1;
	$Counter = 0;
    $elapsed = 60.0 * $whileCounter;
 if($debug eq "yes"){
    my $mod = $whileCounter % 10;#every 10 min to print out infomation	
    if($mod == 0){#every 10 min, print detailed information    
	    if( -e "$sbatch_outdir/dptrain_output/train_done.txt"){
	    	$Counter += 1;			
	    	print "standalone dp train process Done!!!\n";
	    }
	    else{
	    	print "standalone dp train process hasn't done\n";
	    }				 
        
        my $min = $elapsed/(60.);
	    print "\n****Doing while loop times for standalone dp train: $whileCounter\n";
	    print "****Elapsed times: $min min.\n";
	    print "standalone dp trian process done (1) or not (0): $Counter \n\n";
    }
    else{#only check whether all cases have done.
	    if( -e "$sbatch_outdir/dptrain_output/train_done.txt"){
	    	$Counter += 1;			
	    }
    }
 }#debug if
}

my $dpcheck = `grep "finished training" $sbatch_outdir/dptrain_output/standalone_dptrain.dpout`;

if($dpcheck){#standalone done
    print "standalone dp train done!\n";
}
else{
    die "standalone dp train failed!\n";
}

$elapsed = $elapsed/60.;
print "\n#End of standalone dp train while loop after $elapsed min.\n\n";

#making plots
#test_dir in the future
my $train_dir = "$dptrain_setting{work_dir}/train_npy";#collect all training npys
my $validation_dir = "$dptrain_setting{work_dir}/validation_npy";

`rm -rf $train_dir`;
`mkdir -p $train_dir`;
`rm -rf $validation_dir`;
`mkdir -p $validation_dir`;

for (0..$#allnpy4train){#copy training npy files
    chomp;
    `mkdir -p $train_dir/$_`;
    `cp -r $allnpy4train[$_] $train_dir/$_`;
}

for (0..$#allnpy4valid){#copy validation npy files
    chomp;
    `mkdir -p $validation_dir/$_`;
    `cp -r $allnpy4valid[$_] $validation_dir/$_`;
}

my @make_plots = ("train","validation");
my $graph = "$dptrain_setting{work_dir}/dptrain_output/graph_standalone.pb";
for (0..$#make_plots){
    `rm ./lcurve.out`;#remove old lcurve.out in current dir 
    `rm ./temp.*.out`;#remove old dp test output files in current dir 
    `cp  $dptrain_setting{work_dir}/dptrain_output/lcurve.out ./`;#for loss profiles

     #the following for check pred. and ref. data distributions for energy, force, and virial
     my $source = "$dptrain_setting{work_dir}/$make_plots[$_]"."_npy"; 
     system("source activate deepmd-cpu;dp test -m $graph -s $source -d ./temp.out;conda deactivate");
    # get atom number for normalizing energy
     `mv ./temp.e.out ./tempmod.e.out`;# for the following touch temp.e.out
     my @temp = `grep "#" ./tempmod.e.out|awk '{print \$2}'`;
     chomp @temp;
     my @npypath = map {$_ =~ s/:$//g; $_;} @temp;#remove ":"
     die "not npy dirs for matplot\n" unless(@npypath);
     #chomp @npypath;
     my @atomNo;
     for my $npath (@npypath){
         #$_ =~ s/:$//g;
         #print "path: $_\n";
         my @temp = `cat $npath/coord.raw`;#get how many frames in this raw
         chomp @temp;
         for my $nu (@temp){
             $nu  =~ s/^\s+|\s+$//;
             my @sp = split(/\s+/,$nu);
             chomp @sp;
             my $num = @sp/3;
             push @atomNo,$num;
         }
     }
     my @tempdata = `grep -v "#" ./tempmod.e.out`;
     chomp @tempdata;
     my @data = grep (($_!~m{^\s*$|^#}),@tempdata); # remove blank elements
     my $dataNo = @data;
     my $atomarrayNo = @atomNo;
     die "the data number and atom number array are not equal\n" if($dataNo != $atomarrayNo);
     `touch ./temp.e.out`;
     for my $dt (0..$#data){
         $data[$dt]  =~ s/^\s+|\s+$//;
         #print "\$data[\$dt]: $data[$dt]\n";
         my @temp = split(/\s+/,$data[$dt]);
         chomp @temp;
         #print "dt: $dt, $temp[0] $temp[1]\n";
         $temp[0] = $temp[0]/$atomNo[$dt];
         $temp[1] = $temp[1]/$atomNo[$dt];
         #chmop @temp;
         `echo "$temp[0] $temp[1]" >> ./temp.e.out`;
     }
    # end of energy normalization    
    system ("python dp_plots.py");
    sleep(1);
    `mv ./dp_temp.png $dptrain_setting{work_dir}/$make_plots[$_].png`;    
    #$pm-> finish;
}
#housekeeping
`rm ./lcurve.out`;#remove old lcurve.out in current dir 
`rm ./temp.*.out`;#remove old dp test output files in current dir