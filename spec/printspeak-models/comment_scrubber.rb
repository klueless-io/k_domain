# frozen_string_literal: true

class CommentScrubber < Rails::Html::PermitScrubber
  def initialize
    super
    self.tags = %w(div span ul ol li a i em u b img p br table thead tbody tfoot tr th td)
  end

  def skip_node?(node)
    node.text?
  end
end
