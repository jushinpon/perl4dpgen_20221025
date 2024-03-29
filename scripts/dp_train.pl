=b
conducting dp XX.json 
=cut
use warnings;
use strict;
use JSON::PP;
use Data::Dumper;
use Cwd;
use POSIX;
use Parallel::ForkManager;

sub dp_train{

my ($ss_hr,$dps_hr) = @_;
my $mainPath = $ss_hr->{main_dir};# main path of dpgen folder
my $currentPath = $ss_hr->{script_dir};
my $debug = $ss_hr->{debug};
#print "\$ss_hr->{iter}: $ss_hr->{iter}\n";
$ss_hr->{iter} =~ s/^\s+|\s+$//;#could be "initial dp train" or integer
my $iter;
if ($ss_hr->{iter} =~ /^-?\d+\.?\d*$/){
    $iter = "iter". sprintf("%03d",$ss_hr->{iter});
}
else{
    $iter = $ss_hr->{iter};
}

my @allnpy_folder = @{$dps_hr->{allnpy_dir}};
my @type_map = @{$dps_hr->{type_map}};
my $working_dir = $dps_hr->{working_dir};#training folder
my $json_script = $dps_hr->{json_script};#json template
my $json_outdir = $dps_hr->{json_outdir};#modified json output dir
#### modify json file for dpmd-kit, need to be done in main script
my $json;
{
    local $/ = undef;
    open my $fh, '<', "$json_script" or die "no template.json in scripts path $json_script\n";
    $json = <$fh>;
    close $fh;
}
my $decoded = decode_json($json);

#get training and validation folders
my @allnpy_Trafolder;
my @allnpy_Valfolder;

for my $v (@allnpy_folder){
    #print "$v\n";
    if($v =~ /.+\/val$/){
        push @allnpy_Valfolder,$v; 
    }
    else{
        push @allnpy_Trafolder,$v; 
    }
}
die "No val folder for your system. Try to  use a smaller number for \$set_No in all_setting.pm" unless(@allnpy_Trafolder);
map { s/^\s+|\s+$//g; } @allnpy_Valfolder;
map { s/^\s+|\s+$//g; } @allnpy_Trafolder;
##modify set folders' parent path
$decoded->{training}->{training_data}->{systems} = [@allnpy_Trafolder];#clean it first
#find folders with /val
$decoded->{training}->{validation_data}->{systems} = [@allnpy_Valfolder];#clean it first
$decoded->{model}->{type_map} = [@type_map];#clean it first
###
my $trainNo = $ss_hr->{trainNo};
my $trainstep = $dps_hr->{trainstep};
my $forkNo = $trainNo;# $trainNo;
my $pm = Parallel::ForkManager->new("$forkNo");
#make json for original dp train
for (1..$trainNo){
    $pm->start and next;
    my $temp = sprintf("%02d",$_);
    chomp $temp;
    my $seed1 = ceil(12345 * (rand() + $_ * rand()) );
	chomp $seed1;
    $decoded->{model}->{descriptor}->{seed} = $seed1;
    my $seed2 = ceil(12345 * (rand() + $_ * rand()));
	chomp $seed2;
    $decoded->{model}->{fitting_net}->{seed} = $seed2;
    my $seed3 = ceil(12345 * (rand() + $_ * rand()));
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
        open my $fh, '>', "$json_outdir/graph$temp.json";
        print $fh JSON::PP->new->pretty->encode($decoded);#encode_json($decoded);
        close $fh;
    }
     $pm-> finish;
}
$pm->wait_all_children;

#make json for compress dp train
my $compresstrainstep = $dps_hr->{compresstrainstep};

for (1..$trainNo){
    $pm->start and next;
    my $temp = sprintf("%02d",$_);
    chomp $temp;
    my $seed1 = ceil(12345 * (rand() + $_ * rand()) );
	chomp $seed1;
    $decoded->{model}->{descriptor}->{seed} = $seed1;
    my $seed2 = ceil(12345 * (rand() + $_ * rand()));
	chomp $seed2;
    $decoded->{model}->{fitting_net}->{seed} = $seed2;
    my $seed3 = ceil(12345 * (rand() + $_ * rand()));
    chomp $seed3;
    $decoded->{training}->{seed} = $seed3;
    $decoded->{training}->{numb_steps} = $compresstrainstep; 
    $decoded->{training}->{save_ckpt} = $dps_hr->{save_ckpt4compress};;    
    $decoded->{training}->{disp_file} = $dps_hr->{disp_file4compress};;    
    $decoded->{training}->{save_freq} = $dps_hr->{save_freq};    
    $decoded->{training}->{disp_freq} = $dps_hr->{disp_freq};    
    $decoded->{learning_rate}->{start_lr} = $dps_hr->{start_lr4compress};    
    $decoded->{learning_rate}->{decay_steps} = $dps_hr->{decay_steps};    
    $decoded->{model}->{descriptor}->{rcut} = $dps_hr->{rcut};    
    $decoded->{model}->{descriptor}->{rcut_smth} = $dps_hr->{rcut_smth};    
    $decoded->{model}->{descriptor}->{type} = $dps_hr->{descriptor_type};    
       
    {
        local $| = 1;
        open my $fh, '>', "$json_outdir/graph$temp-compress.json";
        print $fh JSON::PP->new->pretty->encode($decoded);#encode_json($decoded);
        close $fh;
    }
     $pm-> finish;
}
$pm->wait_all_children;

##conducting dp_train 
for (1..$trainNo){
    $pm->start and next;
    my $temp = sprintf("%02d",$_);
    chomp $temp;
    chdir("$mainPath/dp_train/graph$temp/");
    system("rm -rf *");
	system("sbatch ../slurm_dp$temp.sh");
    #slurm
	chdir("$currentPath");
    $pm-> finish;
}
$pm->wait_all_children;

### check whether all dp train processes are done
print "\n\n#Beginning dp train while loop at $iter.\n";
my $whileCounter = 0;
my $Counter = 0;
my $elapsed;
while ($whileCounter <= 5000 and $Counter != $trainNo ){
	sleep(60);
    $whileCounter += 1;
	$Counter = 0;
    $elapsed = 60.0 * $whileCounter;
 if($debug eq "yes"){
    my $mod = $whileCounter % 10;#every 10 min	
    if($mod == 0){#every 10 min, print detailed information    
	    for (1..$trainNo){	
	    	my $temp = sprintf("%02d",$_);
            chomp $temp;
	    		if( -e "$mainPath/dp_train/graph$temp/train_done.txt"){
	    			$Counter += 1;			
	    			print "graph$temp dp train process Done!!!\n";
	    		}
	    		else{
	    			print "graph$temp dp train process hasn't done\n";
	    		}				 
	    }
        
        my $min = $elapsed/(60.);
	    print "\n****Doing while loop times for dp train: $whileCounter at $iter\n";
	    print "****Elapsed times: $min min.\n";
        print "total dp trian process number: $trainNo\n";
	    print "Current number with dp trian process done: $Counter from $trainNo jobs\n\n";
    }
    else{#only check whether all cases have done.
          for (1..$trainNo){	
	            my $temp = sprintf("%02d",$_);
                  chomp $temp;
	            if( -e "$mainPath/dp_train/graph$temp/train_done.txt"){
	            	$Counter += 1;			
	            }
          }
    }
 }#debug if
}
$elapsed = $elapsed/60.;
print "\n#End of dp train while loop after $elapsed min at $iter.\n\n";

# check whether setting status of each node is OK
}# end sub
1;