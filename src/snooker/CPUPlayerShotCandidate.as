package snooker {
    
    public final class CPUPlayerShotCandidate {
        
        /**
         * The ball intended to be hit by the cue ball in the shot.
         */
        public var targetBall: Ball;
        
        /**
         * The x coordinate of the cue ball at the point where it hits the target ball.
         */
        public var impactX: Number;
        
        /**
         * The y coordinate of the cue ball at the point where it hits the target ball.
         */
        public var impactY: Number;
        
        /**
         * The x component of the unit vector of the direction of the target ball after being hit
         * by the cue ball.
         */
        public var targetDirX: Number;
        
        /**
         * The y component of the unit vector of the direction of the target ball after being hit
         * by the cue ball.
         */
        public var targetDirY: Number;
        
        /**
         * The x component of the unit vector of the direction in which the cue ball is hit.
         */
        public var shotDirX: Number;
        
        /**
         * The x component of the unit vector of the direction in which the cue ball is hit.
         */
        public var shotDirY: Number;
        
        /**
         * The speed at which the cue ball is hit.
         */
        public var shotSpeed: Number;
        
        /**
         * A value (0-2) indicating the state of the cue ball at the end of the shot:
         * 0: Cue ball's final position is determined, will not enter a pocket.
         * 1: Cue ball will enter a pocket after hitting the target.
         * 2: Cue ball's final state cannot be determined.
         */
        public var postImpactCueBallState: int;
        
        /**
         * The x coordinate of the cue ball's stopping position. Only applicable when postImpactCueBallState
         * is set to 0.
         */
        public var cueBallStopX: Number;
        
        /**
         * The x coordinate of the cue ball's stopping position. Only applicable when postImpactCueBallState
         * is set to 0.
         */
        public var cueBallStopY: Number;
        
        /**
         * A score given to the shot candidate indicating its likelihood of being selected.
         */
        public var score: Number;
        
        /**
         * A score based on the future shots possible from the cue ball's stopping position after the shot.
         * Only applicable when postImpactCueBallState is set to 0.
         */
        public var futureShotBestScore: Number;
        
        /**
         * An array containing the target balls of the possible future shots from the cue ball's stopping position
         * (upto a maximum limit, currently set at 4).
         * Only applicable when postImpactCueBallState is set to 0.
         */
        public var futureShotTargets: Vector.<Ball> = new Vector.<Ball>(4);
        
    }

}