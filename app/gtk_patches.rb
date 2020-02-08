module GTK
  class Controller
    def up
      key_down.up || key_held.up
    end

    def down
      key_down.down || key_held.down
    end

    def left
      key_down.left || key_held.left
    end

    def right
      key_down.right || key_held.right
    end

    def directional_vector
      lr, ud = [left_right, up_down]

      if lr == 0 && ud == 0
        nil
      elsif lr.abs == ud.abs
        [lr.half, ud.half]
      else
        [lr, ud]
      end
    end
  end
end

class Numeric
  def pos?
    sign > 0
  end

  def neg?
    sign < 0
  end
end
