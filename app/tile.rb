module Tile
  def self.grid
    $gtk.args.grid
  end

  def self.grid_tiles w, h
    grid.w
        .idiv(w).+(1)
        .map_with_ys(grid.h.idiv(h).+(1)) do |x, y|
      { x: x * w, y: y * h, w: w, h: h }
    end
  end

  def self.find_intersection with, tiles
    return nil if !with
    return nil if !tiles
    tiles.find { |t| t.intersect_rect? with }
  end

  def self.find_intersection_in_many withs, tiles
    return nil if !withs
    return nil if !tiles
    withs.map { |w| find_intersection w, tiles }.first
  end

  def self.find_intersections with, tiles
    return [] if !with
    return [] if !tiles
    tiles.find_all { |t| t.intersect_rect? with }
  end
end
