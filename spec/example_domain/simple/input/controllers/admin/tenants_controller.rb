class Admin::TenantsController < Admin::BaseController
  include Respondable

  before_action :require_super_user
  before_action :set_tenant, only: %i[show edit update destroy]

  def index
    @tenants = Tenant.where.not(printsmith_ip: nil).order(inital_import_complete: :desc)
  end

  def show
  end

  def new
    @tenant = Tenant.new
  end

  def edit
    # @report = Report.find(params[:id])
  end

  def create
    @tenant = Tenant.new(tenant_params)

    responder_create(@tenant, "Tenant was successfully created.")
  end

  def update
    respond_to do |format|
      if @tenant.update(tenant_params)
        format.html { redirect_to admin_tenant_path(@tenant), notice: "Tenant was successfully updated." }
      else
        format.html { render action: "edit" }
      end
    end
  end

  def destroy
    @tenant.destroy
    respond_to do |format|
      format.html { redirect_to tenants_url }
    end
  end

  private
    def set_tenant
      @tenant = Tenant.find(params[:id])
    end

    def tenant_params
      params.require(:tenant).permit(:name,
                                     :number,
                                     :printsmith_ip,
                                     :printsmith_username,
                                     :printsmith_password,
                                     :printsmith_database,
                                     :printsmith_local_port,
                                     :allow_access,
                                     :time_zone,
                                     :address_1,
                                     :address_2,
                                     :suburb,
                                     :state,
                                     :postcode,
                                     :email_marketing,
                                     :phone,
                                     :contact_name,
                                     :beta_tester,
                                     :display_month_first,
                                     :business_hours,
                                     :pgdump_path,
                                     :backup_path,
                                     :local_path,
                                     :campaign_min_resend_days,
                                     :marketing_name,
                                     :test_email,
                                     :sms_send_number)
    end
end
