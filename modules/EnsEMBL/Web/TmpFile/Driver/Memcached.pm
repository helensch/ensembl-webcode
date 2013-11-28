=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::TmpFile::Driver::Memcached;

use strict;
use Compress::Zlib;

use EnsEMBL::Web::Cache;

sub new {
  my $class = shift;
  my $self  = {};
  
  bless $self, $class;
  $self->{'memd'} = EnsEMBL::Web::Cache->new or return undef;

  return $self;
}

sub memd { $_[0]->{'memd'}; }

sub exists {
  my ($self, $obj) = @_;
  return $self->memd->get($obj->URL);
}

sub delete {
  my ($self, $obj) = @_;
  return $self->memd->delete($obj->URL);
}

sub get {
  my ($self, $obj) = @_;

  $self->memd->enable_compress($obj->compress);
  return $self->memd->get($obj->URL);
}

sub save {
  my ($self, $obj) = @_;

  $self->memd->enable_compress($obj->compress);

  return $self->memd->set(
    $obj->URL,
    $obj->content,
    $obj->exptime,
    ('TMP', $obj->extension, values %{$ENV{'CACHE_TAGS'} || {}}),
  );
}


1;