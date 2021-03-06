# Copyright 2014 European Molecular Biology Laboratory - European Bioinformatics Institute
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
package EpiRR::App::Controller;

use Moose;
use Carp;
use EpiRR::Parser::JsonParser;
has 'output_service' => (
    is       => 'rw',
    isa      => 'EpiRR::Service::OutputService',
    required => 1,
);
has 'schema' => ( is => 'rw', isa => 'EpiRR::Schema', required => 1 );

sub fetch_current {
    my ($self) = @_;

    my $os                = $self->output_service();
    my @current_data_sets = $self->schema()->dataset_version()->search(
        { is_current => 1 },
        {
            prefetch => {
                dataset => ['project'],
                type    => [],
                status  => [],
            },
            collapse => 1,
        }
    );
    my @dsv = map { $os->db_to_user_summary($_) } @current_data_sets;
    return \@dsv;
}

sub fetch_current_full {
    my ($self) = @_;

    my $os                = $self->output_service();
    my @current_data_sets = $self->schema()->dataset_version()->search(
        { is_current => 1 },
        {
            prefetch => {
                dataset => ['project'],
                type    => [],
                status  => [],
            },
            collapse => 1,
        }
    );
    my @dsv = map { $os->db_to_user($_) } @current_data_sets;
    return \@dsv;
}

sub fetch_summary {
    my ($self) = @_;

    my (%project_summary, %status_summary, %all_summary );
    my @summary = $self->schema()->dataset_version()->search(
        { is_current => 1 },
        {
            join   => [ 'status', { 'dataset' => 'project' } ],
            select => [
                'status.name', 'project.name',
                { count => 'dataset_version_id' }
            ],
            as       => [qw(status_name project_name dataset_count)],
            group_by => [ 'status.name', 'project.name' ],
            order_by => [ 'project.name', 'status.name' ],
        },
    );

    @summary = map {
        {
            project       => $_->get_column('project_name'),
            status        => $_->get_column('status_name'),
            dataset_count => $_->get_column('dataset_count')
        }
    } @summary;

      foreach my $summary_entry ( @summary ){
        my $project_name = $summary_entry->{project};
        
	#Skip HipSci
        next if($project_name eq "HipSci");

	my $status = $summary_entry->{status};
        my $dataset_count = $summary_entry->{dataset_count};

        $project_summary{$project_name} += $dataset_count;
        $status_summary{$status} += $dataset_count;
        $all_summary{$project_name}{$status} = $dataset_count;
      }
    return \%project_summary, \%status_summary, \%all_summary;
}

sub fetch {
    my ( $self, $id ) = @_;

    my $data_set = $self->schema->dataset()->find( { accession => $id, } );
    my $data_set_version;

    if ($data_set) {
        $data_set_version =
          $data_set->search_related( 'dataset_versions', { is_current => 1 } )
          ->first();
    }

    if ( !$data_set_version ) {
        $data_set_version =
          $self->schema->dataset_version()->find( { full_accession => $id } );
    }

    if ($data_set_version) {
        return $self->output_service()->db_to_user($data_set_version);
    }
    else {
        return;
    }
}
__PACKAGE__->meta->make_immutable;
1;
