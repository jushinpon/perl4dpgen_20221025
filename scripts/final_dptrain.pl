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

sub final_dptrain{

my ($ss_hr,$dps_hr) = @_;
my $mainPath = $ss_hr->{main_dir};# main path of dpgen folder
my $currentPath = $ss_hr->{script_dir};
my @allnpy_folder = @{$dps_hr->{allnpy_dir}};
my @type_map = @{$dps_hr->{type_map}};
my $trainstep = $dps_hr->{final_trainstep};
my $compresstrainstep = $dps_hr->{final_compresstrainstep};
my $working_dir = "$mainPath/final_dptrain";#training folder
my $json_script = $dps_hr->{json_script};#json template
my $json_outdir = $working_dir;#modified json output dir
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
$decoded->{training}->{systems} = [@allnpy_folder];#clean it first
$decoded->{model}->{type_map} = [@type_map];#clean it first
###
#make json for original dp train
    my $seed1 = ceil(12345 * (rand() + $_ * rand()) );
	chomp $seed1;
    $decoded->{model}->{descriptor}->{seed} = $seed1;
    my $seed2 = ceil(12345 * (rand() + $_ * rand()));
	chomp $seed2;
    $decoded->{model}->{fitting_net}->{seed} = $seed2;
    my $seed3 = ceil(12345 * (rand() + $_ * rand()));
    chomp $seed3;
    $decoded->{training}->{seed} = $seed3;
    $decoded->{training}->{stop_batch} = $trainstep;    
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
        open my $fh, '>', "$json_outdir/graph.json";
        print $fh JSON::PP->new->pretty->encode($decoded);#encode_json($decoded);
        close $fh;
    }
#make json for compress dp train


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
    $decoded->{training}->{stop_batch} = $compresstrainstep; 
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


# check whether setting status of each node is OK
}# end sub
1;