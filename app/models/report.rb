class Report < ActiveRecord::Base
  include AASM

  belongs_to :precinct
  belongs_to :user

  enum source: [:microsoft, :captain, :crowd, :manual]

  default_scope -> { order(created_at: :desc) }

  serialize :delegate_counts
  serialize :results_counts

  validates :precinct_id, :aasm_state, :total_attendees, presence: true

  aasm do
    state :start, initial: true
    state :viability
    state :not_viable
    state :apportionment
    state :apportioned

    event :begin do
      transitions from: :start, to: :viability
    end

    event :viable do
      transitions from: :viability, to: :apportionment
    end

    event :not_viable do
      transitions from: :viability, to: :not_viable
    end

    event :apportion do
      transitions from: :apportionment, to: :apportioned
    end
  end

  def candidate_count(key)
    (delegate_counts || {})[key.intern] || 0
  end

  def candidate_delegates(key)
    if (results_counts || {})[key]
      # If we have a Microsoft report, return it
      results_counts[key]
    else
      return 0 if total_attendees == 0
      # Calculate the pre-adjustment total: delegates * candidate supporters / total attendees
      # (with normal math rounding)
      calculated_total = (candidate_count(key).to_f * precinct.total_delegates.to_f / total_attendees.to_f).round.to_i

      # See if any adjustments are needed
      # A candidate who is viable must receive at least 1 delegate, even if some supporters leave and they
      # would drop below 0.5 in the above calculation.
      adjustment_keys = adjust_keys?
      if adjustment_keys.any?
        # If the adjustment_keys include this candidate's key, this candidate is the recipient of the
        # guaranteed minimum delegate.
        return 1 if adjustment_keys.include? key

        # If not, determine if this is the candidate with the next-fewest delegates.
        deduct_key = delegate_counts.sort_by { |_, v| v }.to_h.select { |_, v| v > threshold }.keys.first

        # If this candidate has the next-fewest delegates, they have 1 taken from them to give to the lowest.
        # Theoretically, 2 delegates could be taken from #1 (to give to #2 and #3 to satisfy the requirement),
        # so we subtract the number of adjusted delegates needed.
        calculated_total -= adjustment_keys.count if key == deduct_key
      end

      # If no adjustments, return 0 if candidate is under the threshold, or else their calculated total as normal.
      return 0 unless above_threshold?(key)
      calculated_total
    end
  end

  def threshold
    multiplier =
      if precinct.total_delegates == 1
        0.50
      elsif precinct.total_delegates == 2
        0.25
      elsif precinct.total_delegates == 3
        1.0 / 6.0
      else
        0.15
      end
    (total_attendees.to_f * multiplier).ceil
  end

  def above_threshold?(key)
    candidate_count(key) >= threshold
  end

  def viable?(key)
    above_threshold?(key) || precinct.reports.captain.apportionment.exists?(user: user) && precinct.reports.captain.apportionment.find_by(user: user).above_threshold?(key)
  end

  private

  def adjust_keys?
    return [] unless captain?
    keys = Candidate.keys.map do |key|
      key.intern if !above_threshold?(key) && viable?(key)
    end
    keys.compact
  end
end
