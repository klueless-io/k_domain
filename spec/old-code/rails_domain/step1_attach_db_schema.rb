log.warn snake.parse('RailsDomainActions-Step1AttachDbSchema') if AppDebug.require?

# Attach the Rails DB Schema to the domain modal under the [:database] key
class Step1AttachDbSchema < RailsDomain::Step
  # Map database schema to domain model
  def run(domain_data:, schema: )
    self.domain_data = domain_data
    
    attach_database(schema)
  end

  private

  def attach_database(schema)
    domain_data[:database] = schema.clone
    
    guard('tables are missing')               if database[:tables].nil?
    guard('indexes are missing')              if database[:indexes].nil?
    guard('foreign keys are missing')         if database[:foreign_keys].nil?
    guard('rails version is missing')         if database[:meta][:rails].nil?
    guard('postgres extensions are missing')  if database[:meta][:database][:extensions].nil?
    guard('unique keys are missing')          if database[:meta][:unique_keys].nil?
  end
end
