module SourcesHelper

  def property_path_from_source(source_id)
    property_id = condenser_get_property_id(source_id)
    return nil unless property_id
    source_path(property_id)
  end

end
