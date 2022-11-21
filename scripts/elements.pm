##This module is developed by Prof. Shin-Pon JU at NSYSU on March 28 2021
package elements; 

use strict;
use warnings;

our (%element); # density (g/cm3), arrangement, mass, lat a , lat c

#$element{"N"} = [1.251,"hcp",14.007,3.861,6.265]; 
$element{"Fe"} = [7.874,"bcc",55.845,2.8665,2.8665]; 
$element{"Na"} = [0.968,"bcc",22.98977,4.2906,4.2906]; 
$element{"O"} = [1.429,"fcc",15.9994,5.403,5.086]; 
$element{"P"} = [1.823,"bcc",30.973761,1.25384,1.24896]; 

sub eleObj {# return properties of an element
   my $elem = shift @_;
   if(exists $element{"$elem"}){
    return (@{$element{"$elem"}});      
   }
   else{
      die "element information of \"$_\" is not listed in elements.pm.",
      " You need to add Al according to the format of density (g/cm3), arrangement, mass, lat a , lat c. ",
      ' For example, $element{"Nb"} = [8.57,"bcc",92.90638,3.30,3.30]'."\n"; 
   }
}
1;               # Loaded successfully
