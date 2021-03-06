module Api
  module V1
    class ReportsController < ApplicationController
      skip_before_action :authenticate!, only: [:create]

      def show
        authorize! :read, current_report
        render json: ReportSerializer.root_hash(current_report)
      end

      def create
        report = current_precinct.reports.new(report_params)
        authorize! :create, report
        if report.save
          render json: ReportSerializer.root_hash(report), status: :created
        else
          render json: report.errors.inspect, status: :unprocessable_entity
        end
      end

      def update
        authorize! :admin, current_report

        rp = report_params
        rp.delete(:source)
        if current_report.update(rp)
          render json: ReportSerializer.root_hash(current_report), status: :ok
        else
          render json: { error: current_report.errors.inspect }, status: :unprocessable_entity
        end
      end

      def destroy
        authorize! :destroy, current_report
        current_report.destroy

        head :no_content
      end

      private

      def current_precinct
        @current_precinct ||= Precinct.find(params[:precinct_id])
      end

      def current_report
        @current_report ||= current_precinct.reports.find_by(id: params[:id])
      end

      def report_params
        rp = params.require(:report).permit(:total_attendees, :phase, delegate_counts: [:key, :supporters], results_counts: [:key, :delegates])

        phase = rp.delete(:phase)
        rp[:aasm_state] = phase if phase && Report.aasm.states.map(&:name).include?(phase.intern)

        # Update delegate counts
        delegate_counts = current_report.try(:delegate_counts) || {}
        (rp.delete(:delegate_counts) || []).each do |delegate|
          next unless Candidate.keys.include? delegate['key']
          delegate_counts[delegate['key'].intern] = delegate['supporters'].to_i
        end
        rp[:delegate_counts] = delegate_counts

        # Update results counts
        results_counts = current_report.try(:results_counts) || {}
        (rp.delete(:results_counts) || []).each do |delegate|
          next unless Candidate.keys.include? delegate['key']
          results_counts[delegate['key'].intern] = delegate['delegates'].to_i
        end
        rp[:results_counts] = results_counts

        rp[:source] =
          if logged_in?
            current_user.organizer? ? :manual : :captain
          else
            :crowd
          end

        rp
      end
    end
  end
end
