package snooker {
    
    public final class Ball {
        
        /**
         * The ball's colour point value (1-7, 0 for the cue ball)
         */
        public var colour: int;
        
        /**
         * A value (0-3) indicating whether a ball is potted or has entered a pocket:
         * 0: Ball is on the table.
         * 1: Ball has been potted, but it is not known whether another collision has
         *    occured earlier.
         * 2: Ball has been potted in the current shot, may be respotted at the end of the shot.
         * 3: Ball is permanently potted.
         */
        public var potStatus: int;
        
        /**
         * The x coordinate of the ball's centre, in the game engine's coordinate system.
         */
        public var x: Number;
        
        /**
         * The y coordinate of the ball's centre, in the game engine's coordinate system.
         */
        public var y: Number;
        
        /**
         * The x component of the ball's velocity vector.
         */
        public var vx: Number;
        
        /**
         * The y component of the ball's velocity vector.
         */
        public var vy: Number;
        
        // These fields are used to store the future state of the ball (at the end of the frame)
        // before checking for collisions.
        public var x2: Number;
        public var y2: Number;
        public var vx2: Number;
        public var vy2: Number;
        
        // These fields are used to store the post-collision velocity components (vxc and vyc) when
        // a ball encounters a collision.
        public var vxc: Number;
        public var vyc: Number;
        
    }

}