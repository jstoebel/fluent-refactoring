class InstallationsController < ActionController::Base
  # lots more stuff...

  def schedule
    desired_date = params[:desired_date]

    if request.xhr?
      xhr_schedule desired_date
    else
      plain_request_schedule desired_date
    end
  end

  private

  def xhr_schedule(desired_date)
    if @installation.pending_credit_check?
      return render json: {
        errors: ['Cannot schedule installation while credit check is pending']
      }, status: 400
    end

    audit_trail_for(current_user) do
      unless @installation.schedule!(
        desired_date,
        schedule_params
      )
        error_messages = @installation.errors.full_messages.join(' ')
        msg = "Could not update installation. #{error_messages}"
        return render json: {
          errors: [msg]
        }
      end

      next unless @installation.scheduled_date

      date = @installation
             .scheduled_date
             .in_time_zone(@installation.city.timezone)
             .to_date

      render json: { errors: nil, html: schedule_response(@installation, date) }
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: [e.message] }
  rescue ArgumentError
    error_msg = 'Could not schedule installation. Start by making sure the desired date is on a business day.' # rubocop:disable Metrics/LineLength
    render json: { errors: [error_msg] }
  end

  def plain_request_schedule(desired_date)
    if @installation.pending_credit_check?
      flash[:error] = "Cannot schedule installation while credit check is pending"
      redirect_to installations_path(:city_id => @installation.city_id, :view => "calendar") and return
    end
    begin
      audit_trail_for(current_user) do
        unless @installation.schedule!(
          desired_date,
          installation_type: params[:installation_type],
          city: @city
        )
          flash[:error] = %(Could not schedule installation, check the phase of the moon)
          next
        end

        next unless @installation.scheduled_date

        if @installation.customer_provided_equipment?
          flash[:success] = %Q{Installation scheduled}
        else
          flash[:success] = %Q{Installation scheduled! Don't forget to order the equipment also.}
        end
      end # do block
    rescue => e
      flash[:error] = e.message
    end
    redirect_to(@installation.customer_provided_equipment? ? customer_provided_installations_path : installations_path(:city_id => @installation.city_id, :view => "calendar"))
  end
  # lots more stuff...

  private

  def schedule_params
    { installation_type: params[:installation_type], city: @city }
  end
end
