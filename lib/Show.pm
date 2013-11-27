package Show;
use Moose;

has 'title' => (is => 'ro', isa => 'Str');
has 'author' => (is => 'ro', isa => 'Str');
has 'director' => (is => 'ro', isa => 'Str');
has 'place' => (is => 'ro', isa => 'Str');
has 'dates' => (is => 'rw', isa => 'ArrayRef[Str]');

__PACKAGE__->meta->make_immutable;
1;
