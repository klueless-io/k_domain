# Run

KManager.action do
  def on_action
  end
end

KManager.opts.app_name                    = 'KDomain Generator'
KManager.opts.sleep                       = 5
KManager.opts.reboot_on_kill              = 0
KManager.opts.reboot_sleep                = 4
KManager.opts.exception_style             = :short
KManager.opts.show.time_taken             = true
KManager.opts.show.finished               = true
KManager.opts.show.finished_message       = 'FINISHED :)'

