# Copyright 2013 European Molecular Biology Laboratory - European Bioinformatics Institute
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
package EpiRR::Service::ENCODEfile;

use Moose;
use namespace::autoclean;
use Carp;
use File::Spec;
use feature qw(say);
use Data::Dumper;

use EpiRR::Parser::ENCODEXMLParser;

with 'EpiRR::Roles::ArchiveAccessor' ;
# what this Module handles
has '+supported_archives' => ( default => sub { [ 'ENCODE' ] }, );

has 'xml_parser' => (
    is       => 'rw',
    isa      => 'EpiRR::Parser::ENCODEXMLParser',
    required => 1,
    default  => sub { EpiRR::Parser::ENCODEXMLParser->new },
    lazy     => 1
);
has 'base_path' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has 'cache_experiments' => (
  is  => 'rw',
  isa => 'HashRef',
);

has 'cache_samples' => (
  is  => 'rw',
  isa => 'HashRef',
);

has 'is_loaded'=>  (
  is      => 'rw',
  isa     => 'Bool',
  default => 0,
);
# Login required, hence only a base URL
has 'url' => (
  is      => 'rw',
  isa     => 'Str',
  default => 'https://www.encodeproject.org/experiments',
);


# RawData coming from JSON input files:
# "primary_id" 	    : "GSM2191308",
# "secondary_id"    : null,
# "assay_type" 	    : "miRNA-Seq",
# "experiment_type" : "smRNA-Seq"
# "archive_url"     : "http://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSM2191308",
# "archive" 	    : "GEO",


sub lookup_raw_data {
    my ( $self, $raw_data, $errors ) = @_;

    confess("Must have raw data")
      if ( !$raw_data );
    confess("Raw data must be EpiRR::Model::RawData")
      if ( !$raw_data->isa('EpiRR::Model::RawData') );
    confess( "Cannot handle this archive: " . $raw_data->archive() )
      if ( !$self->handles_archive( $raw_data->archive() ) );

    if (! $self->is_loaded) {
      $self->_cache_experiments_samples();
      $self->is_loaded(1);
    }

    my $primary_id = $raw_data->primary_id();
    #my $xml = $self->get_xml( $raw_data->primary_id() );

#    my @parser_errors;
    # TODO: push into errors and continue
    my $experiment 	= $self->cache_experiments->{$primary_id}; 
    my $sample_id       = $self->cache_experiments->{$primary_id}->sample_id();
    my $experiment_type = $self->cache_experiments->{$primary_id}->get_meta_data('experiment_type');
    my $experiment_id   = $self->cache_experiments->{$primary_id}->experiment_id();
    my $assay_type      = $self->cache_experiments->{$primary_id}->get_meta_data('library_strategy');

#    push @$errors,
#      map { $_ . ' for ' . $raw_data->primary_id() } @parser_errors;

    my $sample = $self->cache_samples->{$sample_id};
    confess "No sample for experiment [$primary_id]. SampleID provided [$sample_id]"
      if(!defined $sample);

    my $archive_raw_data;
    $archive_raw_data = EpiRR::Model::RawData->new(
      archive         => $raw_data->archive(),
      primary_id      => $experiment->experiment_id(),
      experiment_type => $experiment->get_meta_data('experiment_type'),
      assay_type      => $experiment->get_meta_data('library_strategy'),
      archive_url     => $self->url,
      secondary_id    => $raw_data->secondary_id(),
    );

    my %raw_meta_data = $experiment->all_meta_data();

    if ( !%raw_meta_data ) {
      print "WARNING: No extra experiment meta data for this dataset\n";
    }
 
    for my $k ( keys %raw_meta_data ) {
      $archive_raw_data->set_meta_data($k, $raw_meta_data{$k});
    }

    ## If molecule and molecule_ontology_uri are still set within the sample XML, copy them over to the experiment
    my $sample_molecule     = $sample->get_meta_data('molecule') if ( $sample->get_meta_data('molecule') );
    my $experiment_molecule = $experiment->get_meta_data('molecule') if ( $experiment->get_meta_data('molecule') );
    if ( defined $sample_molecule && defined $experiment_molecule && ( $sample_molecule ne $experiment_molecule) ) {
      push @$errors, "MOLECULE is defined in both sample & experiment and differs";
    } elsif ( defined $sample_molecule && ! defined $experiment_molecule ) {
      $archive_raw_data->set_meta_data('molecule', $sample->get_meta_data('molecule'));
    }
    
    my $sample_molecule_ontology_uri     = $sample->get_meta_data('molecule_ontology_uri') if ( $sample->get_meta_data('molecule_ontology_uri') );
    my $experiment_molecule_ontology_uri = $experiment->get_meta_data('molecule_ontology_uri') if ( $experiment->get_meta_data('molecule_ontology_uri') );
    if ( defined $sample_molecule_ontology_uri && defined $experiment_molecule_ontology_uri && ( $sample_molecule_ontology_uri ne $experiment_molecule_ontology_uri) ) {
      push @$errors, "MOLECULE_ONTOLOGY_URI is defined in both sample & experiment and differs";
    } elsif ( defined $sample_molecule_ontology_uri && ! defined $experiment_molecule_ontology_uri ) {
      $archive_raw_data->set_meta_data('molecule_ontology_uri', $sample->get_meta_data('molecule_ontology_uri'));
    }
    
    return ( $archive_raw_data, $sample );
}


# Find local files
# Populate caches through ENCODEXMLParser
# Structure:
#   cache_experiments->{primary_id}->{sample_id|library_strategy|experiment_type}
#   cache_samples->{sample_id} = EpiRR::Model::Sample;

sub _cache_experiments_samples {
  my ($self, $err) = @_;
  my $base_path = $self->base_path;

  opendir(my $dh, $base_path) || die "Can't opendir $base_path: $!";
    my @exps    = grep { /experiment/ && !/^\./} readdir($dh);
  closedir($dh);

  my $cache_exps    = {};
  my $cache_samples = {};
  
  for my $exp (@exps) {
    confess "\nExperiment XMLs filenames do not contain expected experiment identifiers (ENCSR......): $exp\n" unless ($exp =~ m/ENCSR\w{6}/); 

    $exp =~ /(ENCSR\w{6})/;
    my $id = $1;

    my $file_exp = File::Spec->catfile($base_path,$id . '_experiment.xml'); 
    my $file_sam = File::Spec->catfile($base_path,$id . '_samples.xml'); 
    confess "Missing Sample File $file_sam" if(! -e $file_sam);
    my $sample     = $self->xml_parser->parse_sample($file_sam, $err);
    my $exp        = $self->xml_parser->parse_experiment($file_exp, $err);

    ##### Merge all Experiments and Samples in one data structure ########
    $self->_merge($exp, $cache_exps);
    $self->_merge($sample, $cache_samples);

  }
  $self->cache_samples($cache_samples);
  $self->cache_experiments($cache_exps);


}
sub _merge {
  my ($self, $hash, $cache) = @_;

  foreach my $key (sort keys %{$hash}){
    #confess "Duplication [$key]" if(exists $cache->{$key});
    $cache->{$key}=$hash->{$key};
  }
}


# Construct full path for different files from JGA
sub _get_file {
  my ($self, $path, $type) = @_;

  my @files;
  opendir(my $dh, $path) || die "Can't opendir $path: $!";
    @files = grep { /$type/ } readdir($dh);
  closedir($dh);

  if( scalar(@files) != 1) {
    confess "More or less than expected [$path] [$type]";
  }
  my $file = File::Spec->catfile($path, $files[0]);
  return $file;

}

sub lookup_sample {
    my ( $self, $sample_id, $errors ) = @_;
    confess("Sample ID is required") unless $sample_id;

    my $xml = $self->get_xml($sample_id);
    my $sample = $self->xml_parser()->parse_sample( $xml, $errors );

    return $sample;
}

__PACKAGE__->meta->make_immutable;
1;

