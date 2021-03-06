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
package EpiRR::Model::RawData;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

with 'EpiRR::Roles::HasMetaData';

has 'archive'         => ( is => 'rw', isa => 'Maybe[Str]' );
has 'primary_id'      => ( is => 'rw', isa => 'Maybe[Str]' );
has 'secondary_id'    => ( is => 'rw', isa => 'Maybe[Str]' );
has 'archive_url'     => ( is => 'rw', isa => 'Maybe[Str]' );
has 'experiment_type' => ( is => 'rw', isa => 'Maybe[Str]' );
has 'assay_type'      => ( is => 'rw', isa => 'Maybe[Str]' );

sub as_string {
    my ($self) = @_;
    my $na = '-';
    return join( ' ',
        $self->archive()      || $na,
        $self->primary_id()   || $na,
        $self->secondary_id() || $na );
}

sub to_hash {
    my ($self) = @_;

    my %raw_meta_data = $self->all_meta_data();

    return {
        'archive'         => $self->archive,
        'primary_id'      => $self->primary_id,
        'secondary_id'    => $self->secondary_id,
        'archive_url'     => $self->archive_url,
        'experiment_type' => $self->experiment_type,
        'assay_type'      => $self->assay_type,
        %raw_meta_data
    };
}

__PACKAGE__->meta->make_immutable;
1;
