module GTK
  class Controller
    def up
      self.key_down.up    || self.key_held.up
    end

    def down
      self.key_down.down  || self.key_held.down
    end

    def left
      self.key_down.left  || self.key_held.left
    end

    def right
      self.key_down.right || self.key_held.right
    end
  end
end
