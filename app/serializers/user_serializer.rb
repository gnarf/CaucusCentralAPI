class UserSerializer < JsonSerializer
  class << self
    def hash(user)
      node = hash_for(user, %w(id first_name last_name email phone_number precinct_id privilege))
      node[:precinct_name] = user.precinct.try(:name)
      node[:precinct_state] = user.precinct.try(:state).try(:code)
      node
    end
  end
end
