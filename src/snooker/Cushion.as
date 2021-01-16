package snooker {
    
    public final class Cushion {
        
        /**
         * The vertices of the cushion, as (x, y) coordinate pairs.
         * The length of this array is twice the number of vertices.
         */
        public var points: Vector.<Number>;
        
        /**
         * The components of the unit vector of the outward normals of the cushion segments, as (x, y)
         * coordinate pairs.
         * The length of this array is twice the number of cushion segments.
         * The normal vector at position i (whose components are at indices 2*i and 2*i+1 in this array)
         * is that of the cushion segment between the vertices at positions i and i+1 (i and 0 for the last one)
         * in the points array.
         */
        public var normals: Vector.<Number>;
        
        /**
         * The components of the unit vector of the outward normals of the cushion vertices, as (x, y)
         * coordinate pairs.
         * The positions are the same as those of the corresponding vertices in the points array.
         * The length of this array is twice the number of cushion segments.
         * These normals are calculated as the angle bisectors of the normals of the two segments meeting
         * at the vertex.
         */
        public var cornerNormals: Vector.<Number>;
        
        /**
         * Creates a new Cushion object.
         * 
         * @param points The vertices of the cushion, as (x, y) coordinate pairs. The length of this array
         * is twice the number of vertices.
         * @param normals The components of the unit vector of the outward normals of the cushion segments, as (x, y)
         * coordinate pairs. The length of this array is twice the number of cushion segments (same as the length
         * of the points array)
         */
        public function Cushion(points: Vector.<Number>, normals: Vector.<Number>) {
            this.points = points;
            this.normals = normals;
            
            // Calculate the corner normals from the segment normals.
            var cornerNormals: Vector.<Number> = new Vector.<Number>(points.length, true);

            for (var i: int = 0, n: int = points.length; i < n; i += 2) {
                var nx: Number = normals[i], ny: Number = normals[int(i + 1)];
                if (i === 0) {
                    nx += normals[int(n - 2)];
                    ny += normals[int(n - 1)];
                }
                else {
                    nx += normals[int(i - 2)];
                    ny += normals[int(i - 1)];
                }

                var nr: Number = 1 / Math.sqrt(nx * nx + ny * ny);
                cornerNormals[i] = nx * nr;
                cornerNormals[int(i + 1)] = ny * nr;
            }

            this.cornerNormals = cornerNormals;
        }
        
    }

}