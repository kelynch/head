class Manuscript < ActiveFedora::Base
  include Hydra::Works::WorkBehavior
  property :title, predicate: ::RDF::Vocab::DC.title, multiple: false do |index|
    index.as :stored_searchable, :facetable
  end

  property :origin, predicate: ::RDF::Vocab::DC.created, multiple: false do |index|
    index.as :stored_searchable
  end

  property :description, predicate: ::RDF::Vocab::DC.description, multiple: false do |index|
    index.as :stored_searchable
  end

  def works_add(work)
    binding.pry()
    self.members.select(&:work?) << work
  end

end
