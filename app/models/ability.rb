class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new

    can [:manage, :admin], :all if user.admin?

    can :read, State do |state|
      user.state == state if user.organizer?
    end

    can :manage, Precinct do |precinct|
      if user.organizer?
        user.state == precinct.state
      elsif user.captain?
        user.precinct == precinct
      end
    end
    can :admin, Precinct do |precinct|
      user.state == precinct.state if user.organizer?
    end

    can :create, Report
    can [:read, :admin], Report do |report|
      user.state == report.precinct.state if user.organizer?
    end

    can :create, Token
    can :destroy, Token do |token|
      user == token.user
    end

    can :manage, User do |u|
      user == u
    end
  end
end
