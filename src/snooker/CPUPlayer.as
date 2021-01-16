package snooker {
    
    import flash.geom.Point;
    
    public final class CPUPlayer {
        
        /**
         * The GameEngine to which the CPU player is linked to.
         */
        private var m_engine: GameEngine;
        
        /**
         * An array contaning the candidate shots (both used and unused).
         */
        private var m_shotCandidates: Vector.<CPUPlayerShotCandidate> = new Vector.<CPUPlayerShotCandidate>();
        
        /**
         * The number of candidate shots which are in use.
         */
        private var m_shotCandidateCount: int;
        
        /**
         * The current shot selection round (1-4)
         */
        private var m_currentRound: int;
        
        /**
         * A temporary Point object.
         */
        private var m_tempPoint: Point = new Point();
        
        public function CPUPlayer(engine: GameEngine) {
           m_engine = engine;
        }
        
        /**
         * Selects a shot and sets the cue's position for that shot.
         */
        public function selectShot(): void {
            _createShotCandidates();
            if (m_engine.currentPlayer === 1)
                _pickShotFromCandidates();
        }
        
        /**
         * Creates a list of candidate shots by evaluating the positions of all the balls on the table.
         */
        private function _createShotCandidates(): void {
            var i: int, n: int;
            var balls: Vector.<Ball> = m_engine.balls;
            var colour: int;
            var sc: CPUPlayerShotCandidate;
            
            // Initialize the shot candidate array.
            for (i = 0, n = m_shotCandidates.length; i < n; i++) {
                sc = m_shotCandidates[i];
                sc.targetBall = null;
                sc.score = 1;
                sc.futureShotTargets.length = 0;
                sc.futureShotBestScore = 0;
            }
            m_shotCandidateCount = 0;
            
            // If the CPU player is in a 'ball-in-hand' situation (such as when the human player potted the
            // cue ball or when opening a frame), if it cannot select any shot candidates in rounds 1 and 2,
            // it can respot the cue ball at another unoccupied random location and repeat the shot selection
            // process a limited number of times (currently set to 3)
            var cueBallRespotAttempts: int = 0;

            if (m_engine.gameState === GameState.CUEBALL_IN_HAND
                || (m_engine.gameState === GameState.CHOOSE_FOUL_PLAYER && m_engine.ballInHandAfterFoul))
            {
                cueBallRespotAttempts = 3;
            }
            
            while (true) {
                // First round of shot selection: Look for shots which can legally pot balls.
                m_currentRound = 1;
                for (i = 1, n = m_engine.ballsOnTableCount; i < n; i++) {
                    colour = balls[i].colour;
                    if ((m_engine.gameState === GameState.CHOOSE_COLOUR) ? colour !== 1 : colour === m_engine.currentColour)
                        _createRound1ShotCandidates(balls[i]);
                }
                
                // At this stage, if the human player committed a foul, the CPU can request a replay if 
                // no shot candidates could be found or if all candidates have scores below a threshold value
                // (currently set at 0.35)
                if (m_engine.gameState === GameState.CHOOSE_FOUL_PLAYER) {
                    var scoresBelowThreshold: Boolean = true;
                    for (i = 0, n = m_shotCandidateCount; i < n; i++) {
                        if (m_shotCandidates[i].score >= 0.35) {
                            scoresBelowThreshold = false;
                            break;
                        }
                    }
                    if (scoresBelowThreshold) {
                        m_engine.setCurrentPlayer(0);
                        return;
                    }
                }
                
                // If first-round shot candidates have been found, evaluate them for future shot and colour-based
                // scores and finish.
                if (m_shotCandidateCount > 0) {
                    _applyFutureShotScores();
                    _applyColourScores();
                    return;
                }
                
                // Second round of shot selection: Direct hit any legal ball (without obstruction, with some
                // exceptions for reds obstructed by other reds only, required e.g. for breaking the red rack)
                m_currentRound = 2;
                for (i = 1, n = m_engine.ballsOnTableCount; i < n; i++) {
                    colour = balls[i].colour;
                    if ((m_engine.gameState === GameState.CHOOSE_COLOUR) ? colour !== 1 : colour === m_engine.currentColour)
                        _createRound2and4ShotCandidates(balls[i]);
                }

                if (m_shotCandidateCount > 0)
                    return;
                    
                if (cueBallRespotAttempts === 0)
                    break;

                // Respot the cue ball and try again
                m_engine.spotCueBallInD();
                cueBallRespotAttempts--;
            }
            
            // Third round of shot selection: Hit any legal ball through a cushion rebound
            // with no obstructions in the path.
            m_currentRound = 3;
            for (i = 1, n = m_engine.ballsOnTableCount; i < n; i++) {
                colour = balls[i].colour;
                if ((m_engine.gameState === GameState.CHOOSE_COLOUR) ? colour !== 1 : colour === m_engine.currentColour)
                    _createRound3ShotCandidates(balls[i]);
            }
            if (m_shotCandidateCount > 0)
                return;
            
            // Fourth round of shot selection: Direct hit any ball (unobstructed, but again with some exceptions
            // for reds). A foul is inevitable at this stage.
            m_currentRound = 4;
            for (i = 1, n = m_engine.ballsOnTableCount; i < n; i++)
                _createRound2and4ShotCandidates(balls[i]);
        }
        
        /**
         * Selects the shot to be executed from the candidate list, and sets the cue's position for that shot
         * in the game engine.
         */
        private function _pickShotFromCandidates(): void {
            // The following picking algorithm is used here:
            // - S is the set of all shot candidates.
            // - Let max_score = Maximum score from all candidates in S.
            // - Let S1 be the set of all candidates in S having a score greater than the cutoff value
            //   The cutoff value is calculated as a1 * max_score, where a1 is the cutoff factor (0 <= a1 < 1)
            // - Let sel_score = (a1 + (1-a1) * (1-u^e)) * max_score
            //   where u is a uniform random number in [0, 1), e is the randomization exponent and a1
            //   is the cutoff factor defined in the previous step.
            //   sel_score will be a value in [a1*max_score, max_score]. Higher values of n result in greater bias
            //   towards the maximum score.
            // - Let first_score be the score of the shot candidate in S1 having a score greater than and
            //   closest to sel_score.
            // - Let S2 be the subset of S1 with all candidates having a score in [first_score, first_score+a2]
            //   where a2 is the neighbourhood delta.
            // - The selected shot is randomly chosen from S2.
            
            // Current parameters:
            var a1: Number = 0.5;
            var a2: Number = 0.03;
            var e: Number = 4;      // Gives E[sel_score] = 0.9 * max_score)

            var candidates: Vector.<CPUPlayerShotCandidate> = m_shotCandidates;
            var score: Number, maxScore: Number = 0;
            var count: int = m_shotCandidateCount;
            var i: int, j: int;
            var tempCandidate: CPUPlayerShotCandidate;
            
            // First get the maximum score.
            for (i = 0; i < count; i++) {
                score = candidates[i].score;
                if (maxScore < score)
                    maxScore = score;
            }
            
            // To make the sorting faster, move all candidates with scores below the cutoff value to the
            // end of the array (as these will not be considered). The candidate count is adjusted accordingly.
            for (i = 0; i < count; i++) {
                if (candidates[i].score < 0.5 * maxScore) {
                    tempCandidate = candidates[i];
                    count--;
                    candidates[i] = candidates[count];
                    candidates[count] = tempCandidate;
                    i--;
                }
            }
            
            m_shotCandidateCount = count;
            
            // Now sort the candidates having scores above the cutoff value in ascending order of their scores.
            for (i = count - 1; i > 0; i--) {
                var swapped: Boolean = false;
                for (j = 0; j < i; j++) {
                    if (candidates[int(j + 1)].score < candidates[j].score) {
                        tempCandidate = candidates[j];
                        candidates[j] = candidates[int(j + 1)];
                        candidates[int(j + 1)] = tempCandidate;
                        swapped = true;
                    }
                }
                if (!swapped)
                    break;
            }
            
            // Now determine the selection score.
            var selectScore: Number = (a1 + (1 - a1) * (1 - Math.pow(Math.random(), e))) * maxScore;
            
            // Determine the start of the selection range. This is the first candidate having a score
            // greater than the selection score.
            var selectedRangeStart: int, selectedRangeEnd: int;
            for (i = 0; i < count; i++) {
                selectedRangeStart = i;
                if (candidates[i].score >= selectScore)
                    break;
            }
            // Determine the end of the selection range.
            selectScore = candidates[selectedRangeStart].score;
            selectedRangeEnd = selectedRangeStart;
            for (i = selectedRangeStart + 1; i < count; i++) {
                if (candidates[i].score - selectScore > a2)
                    break;
                selectedRangeEnd++;
            }
            
            // If the selection range has more than one candidate, select one randomly.
            var selectedCandidate: CPUPlayerShotCandidate;
            if (selectedRangeStart === selectedRangeEnd) {
                selectedCandidate = candidates[selectedRangeStart];
            }
            else {
                j = selectedRangeStart + int((selectedRangeEnd - selectedRangeStart + 1) * Math.random());
                if (j > selectedRangeEnd)
                    j = selectedRangeEnd;
                selectedCandidate = candidates[j];
            }
            
            // The shot to be executed has now been selected.
            // Apply random errors to the shot's speed and angle.
            _applyShotError(selectedCandidate);
            
            // If the CPU player is asked to choose a colour (after potting a red), set the colour of the
            // target ball of the selected shot. (In the unlikely case where this is red, set the colour to
            // yellow)
            if (m_engine.gameState === GameState.CHOOSE_COLOUR) {
                var selectedColour: int = selectedCandidate.targetBall.colour;
                m_engine.setCurrentColour((selectedColour === 1) ? 2 : selectedColour);
            }
            
            // Set the shot parameters to the game engine.
            m_engine.setGameState(selectedCandidate.shotDirX);
            m_engine.setCueDir(selectedCandidate.shotDirX, selectedCandidate.shotDirY);
            m_engine.setBallInHandAfterFoul(false);
            m_engine.setCueBallSpeed(selectedCandidate.shotSpeed);
            m_engine.setGameState(GameState.CUE_SHOT_POWER);
        }
        
        /**
         * Creates a new shot candidate. An existing object is reused if possible.
         * 
         * @return The new CPUPlayerShotCandidate object.
         */
        private function _makeNewShotCandidate(): CPUPlayerShotCandidate {
            var shotCandidate: CPUPlayerShotCandidate;

            if (m_shotCandidateCount === m_shotCandidates.length)
                shotCandidate = m_shotCandidates[m_shotCandidateCount] = new CPUPlayerShotCandidate();
            else
                shotCandidate = m_shotCandidates[m_shotCandidateCount];

            m_shotCandidateCount++;

            shotCandidate.futureShotBestScore = 0;

            for (var i: int = 0; i < 4; i++)
                shotCandidate.futureShotTargets[i] = null;

            shotCandidate.futureShotTargets.length = 0;

            return shotCandidate;
        }
        
        /**
         * Estimates the initial speed required by the ball to attain a given speed after
         * travelling a given dsitance.
         * 
         * @param dist The distance travelled by the ball.
         * @param v1 The speed of the ball after it has travelled the given distance.
         * @return The estimated initial speed of the ball.
         */
        private static function _estimateRequiredSpeed(dist: Number, v1: Number): Number {
            // Friction model parameters: a0 = 0.048, a1 = 0.000045, vt = 0.006
            // (used in game engine, see GameEngine class)
            // Derived values:
            // A = (a0-a1)*vt = 0.00028773
            // B = a1 = 0.000045
            // 1/B = 22222.2222222222, A/(B^2) = 142088.888888889
            
            // Uses Newton-Raphson method to find v0:
            var v0_guess: Number = v1 * 2 + 0.1;
            var v0: Number;
            var k: Number = 1 / (0.00028773 + 0.000045 * v1);

            while (true) {
                var f1: Number = 22222.2222222222 * (v0_guess - v1) - 142088.888888889 * Math.log(k * (0.00028773 + 0.000045 * v0_guess)) - dist;
                var f2: Number = 0.00028773 / v0_guess + 0.000045;

                v0 = v0_guess - f1 * f2;
                if (Math.abs(v0 - v0_guess) <= 1E-6)
                    return v0;

                v0_guess = v0;
            }

            return 0;
        }
        
        /**
         * Estimates the speed of the ball, given its initial speed and distance travelled.
         * 
         * @param dist The distance travelled by the ball.
         * @param v0 The initial speed of the ball.
         * @return The estimated speed of the ball after travelling the given distance.
         */
        private static function _estimateFinalSpeed(dist: Number, v0: Number): Number {
            // Friction model parameters: a0 = 0.048, a1 = 0.000045, vt = 0.006
            // (used in game engine, see GameEngine class)
            // Derived values:
            // A = (a0-a1)*vt = 0.00028773
            // B = a1 = 0.000045
            // 1/B = 22222.2222222222, A/(B^2) = 142088.888888889
            
            // First check if the given distance is more than the stopping distance for v0. If this is so,
            // the ball will never travel the given distance, so return a final speed of 0 (indicating
            // that the ball has stopped)
            if (dist >= _estimateStoppingDistance(v0))
                return 0;
            
            // Uses Newton-Raphson method to find v1:
            var v1_guess: Number = v0 * 0.5;
            var v1: Number;
            var k: Number = 1 / (0.00028773 + 0.000045 * v0);

            while (true) {
                var f1: Number = -22222.2222222222 * (v1_guess - v0) + 142088.888888889 * Math.log(k * (0.00028773 + 0.000045 * v1_guess)) - dist;
                var f2: Number = -0.00028773 / v1_guess - 0.000045;

                v1 = v1_guess - f1 * f2;
                if (Math.abs(v1 - v1_guess) <= 1E-6)
                    return v1;

                v1_guess = v1;
            }

            return 0;
        }
        
        /**
         * Estimates the stopping distance of the ball, given its initial speed.
         * 
         * @param v0 The initial speed of the ball.
         * @return The estimated distance travelled by the ball with the given initial speed, when it stops.
         */
        private static function _estimateStoppingDistance(v0: Number): Number {
            // Friction model parameters: a0 = 0.048, a1 = 0.000045, vt = 0.006
            // (used in game engine, see GameEngine class)
            // Derived values:
            // A = (a0-a1)*vt = 0.00028773
            // B = a1 = 0.000045
            // 1/B = 22222.2222222222, A/(B^2) = 142088.888888889, B/A = 0.1563966218329684
            return v0 * 22222.2222222222 - Math.log(1 + 0.1563966218329684 * v0) * 142088.888888889;
        }
        
        /**
         * Applies random error to the speed and angle of the selected shot.
         * 
         * @param shot The shot candidate which has been selected, for applying random error.
         */
        private function _applyShotError(shot: CPUPlayerShotCandidate): void {
            // If 'u' is a random number in [0, 1) then the angle and speed errors are calculated as:
            // angle_error : If u < u0_angle then angle_error = 0
            //               Otherwise let u1 = (u / u0_angle) * 2 - 1
            //               angle_error = angle_scale * u1 * (|u1|^angle_exp)
            // 
            // speed_error : If u < u0_speed then speed_error = 0
            //               Otherwise let u1 = (u / u0_speed) * 2 - 1
            //               If u1 < 0 then speed_error = -speed_scale_negative * |u1|^speed_exp * original_speed
            //               Otherwise speed_error = speed_scale_positive * |u1|^speed_exp * original_speed
            //               The new speed (after adding speed_error) is clamped to the minimum
            //               and maximum permissible values.
            
            // Current parameters:
            var u0_angle: Number = 0.67,
                u0_speed: Number = 0.75,
                angle_scale_round1: Number = 0.051,
                angle_scale_other: Number = 0.024,
                speed_scale_negative: Number = 0.031,
                speed_scale_positive: Number = 0.047,
                angle_exp: Number = 0.8,
                speed_exp: Number = 1.8;

            // Derived constants:
            var two_over_u0_angle: Number = 2.98507462686567;   // 2/u0_angle
            var two_over_u0_speed: Number = 2.66666666666667;   // 2/u0_speed
            
            // Apply error to shot angle
            // For a first round (targeting) shot, the error is applied to the target angle.
            // For other shots, the error is applied to the shot (cue-ball) angle.
            
            var rnd: Number = Math.random();
            var cueBall: Ball = m_engine.balls[0];

            if (rnd < u0_angle) {
                rnd = rnd * two_over_u0_angle - 1;
                rnd = Math.pow(Math.abs(rnd), angle_exp) * rnd;

                var errorSin: Number, errorCos: Number, newDirX: Number, newDirY: Number;
                
                // Since the angles involved are small, use the approximations sin(x) = x, cos(x) = 1-(x^2)/2
                if (m_currentRound === 1) {
                    errorSin = rnd * angle_scale_round1;
                    errorCos = 1 - 0.5 * errorSin * errorSin;

                    newDirX = shot.targetDirX * errorCos - shot.targetDirY * errorSin;
                    newDirY = shot.targetDirX * errorSin + shot.targetDirY * errorCos;

                    shot.shotDirX = shot.targetBall.x - cueBall.x - 25.2 * newDirX;
                    shot.shotDirY = shot.targetBall.y - cueBall.y - 25.2 * newDirY;

                    var norm: Number = 1 / Math.sqrt(shot.shotDirX * shot.shotDirX + shot.shotDirY * shot.shotDirY);
                    shot.shotDirX *= norm;
                    shot.shotDirY *= norm;
                }
                else {
                    errorSin = rnd * angle_scale_other;
                    errorCos = 1 - 0.5 * errorSin * errorSin;

                    newDirX = shot.shotDirX * errorCos - shot.shotDirY * errorSin;
                    newDirY = shot.shotDirX * errorSin + shot.shotDirY * errorCos;

                    shot.shotDirX = newDirX;
                    shot.shotDirY = newDirY;
                }
            }
            
            // Apply error to shot speed.
            
            rnd = Math.random();
            if (rnd < u0_speed) {
                rnd = (rnd * two_over_u0_speed) - 1;
                var speedScale: Number = (rnd < 0) ? speed_scale_negative : speed_scale_positive;

                shot.shotSpeed += speedScale * Math.pow(Math.abs(rnd), speed_exp) * shot.shotSpeed;

                if (shot.shotSpeed > 1.67)
                    shot.shotSpeed = 1.67;
                else if (shot.shotSpeed < 0.25)
                    shot.shotSpeed = 0.25;
            }
        }
        
        /**
         * Gets the nearest perpendicular distance of a ball on the table (with certain exceptions if specified)
         * to a straight line path. This is used to check for obstructing balls in the path of the cue ball
         * to its target or a target ball to its target pocket, etc.
         * 
         * @param startX The x-coordinate starting point of the path on the table.
         * @param startY The y-coordinate starting point of the path on the table.
         * @param dirX The x component of the unit vector of the path's direction.
         * @param dirY The y component of the unit vector of the path's direction.
         * @param length The distance of the path.
         * @param excludeBall1 This ball will be ignored (if not null).
         * @param excludeBall2 This ball will be ignored (if not null).
         * @param excludeBall3 This ball will be ignored (if not null).
         * @param excludeThresholdColour If this is set to a colour value (0-7), all balls within a threshold
         * distance (given by `excludeThresholdDistance`) of the ending point of the path will be ignored.
         * Set to -1 to disable.
         * @param excludeThresholdDistance This parameter is used in conjunction with `excludeThresholdColour`. It must
         * be greater than 0 if `excludeThresholdColour` is set to anything other than -1.
         * 
         * @return The perpendicular distance of the ball on the table (other than ignored balls) which is
         * nearest to the given line.
         */
        private function _getNearestBallDistanceToPath(
            startX: Number,
            startY: Number,
            dirX: Number,
            dirY: Number,
            length: Number,
            excludeBall1: Ball = null,
            excludeBall2: Ball = null,
            excludeBall3: Ball = null,
            excludeThresholdColour: int = -1,
            excludeThresholdDistance: Number = 0
        ): Number {
            var balls: Vector.<Ball> = m_engine.balls;
            var ballCount: int = m_engine.ballsOnTableCount;
            var endX: Number = startX + length * dirX;
            var endY: Number = startY + length * dirY;
            var thresholdActive: Boolean = excludeThresholdColour !== -1 && excludeThresholdDistance > 0;
            
            var minDist: Number = 5000;   // Set some arbitrarily large value here (should be larger than the table size)
            var rx: Number, ry: Number;
            
            for (var i: int = 0; i < ballCount; i++) {
                var ball: Ball = balls[i];

                if (ball === excludeBall1 || ball === excludeBall2 || ball === excludeBall3)
                    continue;

                if (thresholdActive && ball.colour === excludeThresholdColour) {
                    rx = ball.x - endX;
                    ry = ball.y - endY;
                    if (rx * rx + ry * ry < excludeThresholdDistance * excludeThresholdDistance)
                        continue;
                }

                rx = ball.x - startX;
                ry = ball.y - startY;

                var parallelComponent: Number = rx * dirX + ry * dirY;
                if (parallelComponent <= 0 || parallelComponent > length)
                    continue;

                var normalComponent: Number = Math.abs(rx * dirY - ry * dirX);
                if (minDist > normalComponent)
                    minDist = normalComponent;
            }

            return minDist;
        }
        
        /**
         * Returns a score based on obstructing balls in the path of the target ball to the pocket.
         * 
         * @param pDist The minimum perpendicular distance between any ball on the table in the path
         * of the target ball to the target pocket.
         * 
         * @return A score (between 0 and 1) based on the perpendicular distance of the closest obstructing
         * ball. 0 indicates a definite obstruction; 1 indicates that there is definitely no obstruction.
         */
        private static function _getTargetPathScore(pDist: Number): Number {
            if (pDist <= 20)
                return 0;
            if (pDist <= 25.2)
                return 0.15;
            if (pDist <= 30)
                return 0.75;
            if (pDist <= 36)
                return 0.90;
            return 1;
        }
        
        /**
         * Returns a score based on the angle of deflection of the shot.
         * 
         * @param cosTheta The cosine of the deflection angle.
         * 
         * @return A score (between 0 and 1) based on the angle of deflection. 0 indicates that it is
         * more than the maximum allowed angle; 1 indicates that it is definitely below a 'safe' value.
         */
        private static function _getDeflectionAngleScore(cosTheta: Number): Number {
            if (cosTheta <= 0.0871557)   // 85 deg
                return 0;
            if (cosTheta <= 0.3420201)   // 70 deg
                return 0.45;
            if (cosTheta <= 0.5)         // 60 deg
                return 0.75;
            if (cosTheta <= 0.6427876)   // 50 deg
                return 0.85;
            return 1;
        }
        
        /**
         * Returns a score based on the minimum required shot speed to pot the target ball.
         * 
         * @param shotSpeed The minimum required shot speed to pot the target ball.
         * 
         * @return A score (between 0 and 1) based on the minimum required shot speed to pot the target ball.
         * 1 indicates that the minimum speed is definitely below the maximum possible speed; 0 indicates that
         * it definitely exceeds the maximum allowed.
         */
        private static function _getShotSpeedScore(shotSpeed: Number): Number {
            if (shotSpeed <= 1.50)
                return 1;
            if (shotSpeed <= 1.67)
                return 0.85;
            if (shotSpeed <= 1.75)
                return 0.15;
            return 0;
        }
        
        /**
         * Returns a score based on the distance between the target ball and the target pocket.
         * 
         * @param dist The distance between the target ball and the target pocket.
         * 
         * @return A score (between 0 and 1) based on the distance between the target ball and target pocket.
         * (The further away the target ball is from the pocket, the lower the score)
         */
        private static function _getTargetToPocketDistanceScore(dist: Number): Number {
            if (dist > 1500)
                return 0.60;
            if (dist > 1200)
                return 0.70;
            if (dist > 900)
                return 0.80;
            if (dist > 600)
                return 0.90;
            return 1;
        }
        
        /**
         * Corrects the shot angle to avoid the collision of the target ball with a cushion on its way
         * to the pocket.
         * 
         * @param cushion The cushion to check.
         * @param cushionPoint The corner of the cushion with which the target ball will possibly collide.
         * This is the serial number of the x/y coordinate pair of the cushion point in the `points` vector
         * of the Cushion object.
         * @param targetX The x coordinate of the target ball.
         * @param targetY The y coordinate of the target ball.
         * @param dir A `Point` object containing the x and y components of the direction unit vector of
         * the target ball. If a correction is made, the x/y fields of this object will be set to the
         * corrected direction.
         * 
         * @return True if a correction was made, false if the target's direction is unchanged.
         */
        private static function _applyCushionCorrection(
            cushion: Cushion,
            cushionPoint: int,
            targetX: Number,
            targetY: Number,
            dir: Point
        ): Boolean {
            var cpX: Number = cushion.points[int(cushionPoint * 2)];
            var cpY: Number = cushion.points[int(cushionPoint * 2 + 1)];

            var cnX: Number = cushion.cornerNormals[int(cushionPoint * 2)];
            var cnY: Number = cushion.cornerNormals[int(cushionPoint * 2 + 1)];

            var pX: Number = cpX - targetX;
            var pY: Number = cpY - targetY;

            var pLength: Number = pX * dir.x + pY * dir.y;
            if (pLength < 0)
                return false;
            
            pX = pLength * dir.x - pX;
            pY = pLength * dir.y - pY;
            pLength = pX * pX + pY * pY;

            if (pLength < 158.76) {
                pX = (cpX - targetX) + cnX * 13;
                pY = (cpY - targetY) + cnY * 13;
                
                var norm: Number = 1 / Math.sqrt(pX * pX + pY * pY);
                dir.x = pX * norm;
                dir.y = pY * norm;

                return true;
            }

            return false;
        }
        
        /**
         * Returns a score based on whether the cue ball would enter a pocket after hitting its target.
         * 
         * @param startX The x coordinate of the point of impact of the cue ball with the target.
         * @param startY The y coordinate of the point of impact of the cue ball with the target.
         * @param dirX The x component of the direction unit vector of the cue ball after impact.
         * @param dirY The y component of the direction unit vector of the cue ball after impact.
         * @param stopDistance The distance travelled by the cue ball after impact to come to a stop.
         * @param targetBall The target ball hit by the cue ball.
         * 
         * @return A score (between 0 and 1) based on whether the ball would enter a pocket. (1 indicates
         * that it will not enter a pocket at all)
         */
        private function _getCueBallPocketEntryScore(
            startX: Number,
            startY: Number,
            dirX: Number,
            dirY: Number,
            stopDistance: Number,
            targetBall: Ball
        ): Number {
            var pocketCentres: Vector.<Number> = GameEngine.pocketCentres;
            var score: Number, minScore: Number = 1;
            var cueBall: Ball = m_engine.balls[0];
            
            for (var i: int = 0, n: int = pocketCentres.length; i < n; i += 2) {
                var pocketX: Number = pocketCentres[i];
                var pocketY: Number = pocketCentres[int(i + 1)];

                var tangentDist: Number = (pocketX - startX) * dirX + (pocketY - startY) * dirY;
                var normalDist: Number = Math.abs((pocketX - startX) * dirY - (pocketY - startY) * dirX);

                if (tangentDist < 0 || tangentDist > stopDistance + 22.5 || normalDist > 28) {
                    score = 1;
                }
                else {
                    // The score is calculated from two factors: The perpendicular distance to the pocket
                    // centre (it will enter if this is less than the pocket radius) and any balls in
                    // the path from the cue ball to the pocket. The second score (clearance score) is
                    // obtained using the _getTargetPathScore function.

                    if (normalDist <= 10)
                        score = 0.35;
                    else if (normalDist <= 22.5)
                        score = 0.45;
                    else
                        score = 0.75;

                    var clearanceScore: Number = _getTargetPathScore(
                        _getNearestBallDistanceToPath(startX, startY, dirX, dirY, stopDistance, targetBall, cueBall)
                    );
                    score = 1 - (0.2 + 0.8 * clearanceScore) * (1 - score);
                }

                if (minScore > score)
                    minScore = score;
            }
            
            return minScore;
        }
        
        /**
         * Applies scores to the shot candidates based on the point values of their target colours.
         */
        private function _applyColourScores(): void {
            var candidates: Vector.<CPUPlayerShotCandidate> = m_shotCandidates;
            var candidateCount: int = m_shotCandidateCount;
            var i: int, colour: int;
            
            if (m_currentRound === 1 && m_engine.gameState === GameState.CHOOSE_COLOUR) {
                // If the CPU is asked to choose a colour to pot, examine all shot candidates and
                // assign a colour score to them (which is multiplied with their existing score).
                // The colour score depends on its point value relative to those of other shot candidates.
                
                // The scoring scheme used is as follows:
                // Highest colour: 3.00 (Black)
                //                 2.75 (Pink/Blue)
                //                 2.50 (All other)
                // Second highest colour: 1.45 (Pink)
                //                        1.35 (Blue/Brown)
                //                        1.30 (All other)
                // Third highest colour: 1.20 (All colours)
                
                // To keep track of a colour's rank among the shot candidates, a bit vector is used
                // where the bit for a particular colour is set to 1 if that colour exists in the
                // shot candidate list.
                
                var firstColour: int = 0, secondColour: int = 0;
                var colourBits: int = 0;

                for (i = 0; i < candidateCount; i++) {
                    colour = candidates[i].targetBall.colour;
                    colourBits |= 1 << colour;
                    if (firstColour < colour) {
                        secondColour = firstColour;
                        firstColour = colour;
                    }
                    else if (firstColour !== colour && secondColour < colour) {
                        secondColour = colour;
                    }
                }
                
                // Determine the scores for the first and second ranks (which depend on the
                // absolute point value of the colour, see the scoring scheme above)

                var firstColourScore: Number, secondColourScore: Number;

                if (firstColour === 7)
                    firstColourScore = 3.00;
                else if (firstColour === 6 || firstColour === 5)
                    firstColourScore = 2.75;
                else
                    firstColourScore = 2.50;

                if (secondColour === 6)
                    secondColourScore = 1.45;
                else if (secondColour === 5 || secondColour === 4)
                    secondColourScore = 1.35;
                else
                    secondColourScore = 1.30;
                
                // Now assign the colour scores to the shot candidates.
                for (i = 0; i < candidateCount; i++) {
                    colour = candidates[i].targetBall.colour;
                    var bitsAbove: int = colourBits & ~((1 << (colour + 1)) - 1);
                    
                    // The number of bits set to 1 in bitsAbove indicates how many colours are higher the
                    // shot candidate's target colour. So no bits set indicates the highest colour, one
                    // bit indicates second highest and so on.
                    if (bitsAbove === 0) {
                        candidates[i].score *= firstColourScore;
                    }
                    else {
                        bitsAbove &= bitsAbove - 1;
                        if (bitsAbove === 0) {
                            candidates[i].score *= secondColourScore;
                        }
                        else {
                            bitsAbove &= bitsAbove - 1;
                            candidates[i].score *= (bitsAbove === 0) ? 1.20 : 1.0;
                        }
                    }
                }
                
            }
        }
        
        /**
         * Creates first-round shot candidates for the given target ball.
         * 
         * @param targetBall The target ball.
         */
        private function _createRound1ShotCandidates(targetBall: Ball): void {
            var cueBall: Ball = m_engine.balls[0];
            var cushions: Vector.<Cushion> = GameEngine.cushions;
            var pocketCentres: Vector.<Number> = GameEngine.pocketCentres;
            var cueToTargetX: Number = targetBall.x - cueBall.x;
            var cueToTargetY: Number = targetBall.y - cueBall.y;
            
            if (cueToTargetX * cueToTargetX + cueToTargetY * cueToTargetY < 729)
                return;
            
            for (var i: int = 0, n: int = pocketCentres.length >> 1; i < n; i++) {
                var targetToPocketX: Number = pocketCentres[int(i << 1)] - targetBall.x;
                var targetToPocketY: Number = pocketCentres[int((i << 1) + 1)] - targetBall.y;
                
                // Check that the cue-to-target and target-to-pocket vectors make an angle of
                // less than 90 degrees with each other
                // Otherwise, the target can never be hit into the pocket.
                if (cueToTargetX * targetToPocketX + cueToTargetY * targetToPocketY <= 0)
                    continue;
                
                var targetToPocketDistance: Number = Math.sqrt(targetToPocketX * targetToPocketX + targetToPocketY * targetToPocketY);
                var norm: Number = 1 / targetToPocketDistance;
                targetToPocketX *= norm;
                targetToPocketY *= norm;
                
                // Assign a score for the distance between the target ball and the pocket.
                // (Lower scores are assigned for large distances)
                var targetDistanceScore: Number = _getTargetToPocketDistanceScore(targetToPocketDistance);
                
                // Check if the target ball would collide with a cushion on its way to the pocket.
                // If it does, correct the target angle so that it does not hit the cushion.
                var cushion1: Cushion = cushions[i];
                var cushion2: Cushion = cushions[int((i === n - 1) ? 0 : i + 1)];

                m_tempPoint.x = targetToPocketX;
                m_tempPoint.y = targetToPocketY;

                if (_applyCushionCorrection(cushion1, 2, targetBall.x, targetBall.y, m_tempPoint)
                    || _applyCushionCorrection(cushion2, 1, targetBall.x, targetBall.y, m_tempPoint))
                {
                    targetToPocketX = m_tempPoint.x;
                    targetToPocketY = m_tempPoint.y;
                }
                
                // Assign a target path score based on any obstructions in the path from the target to the pocket.
                // If this score is zero, the shot candidate is ruled out.
                var targetPathScore: Number = _getTargetPathScore(
                    _getNearestBallDistanceToPath(
                        targetBall.x, targetBall.y, targetToPocketX, targetToPocketY, targetToPocketDistance, targetBall
                    )
                );

                if (targetPathScore === 0)
                    continue;
                    
                // Predict the required speed of the target ball to enter the pocket. To compensate for error,
                // keep a residual velocity of 0.02 when the ball is inside the pocket
                var requiredTargetSpeed: Number = _estimateRequiredSpeed(targetToPocketDistance, 0.02);
                
                var cueToImpactX: Number = cueToTargetX - 25.2 * targetToPocketX;
                var cueToImpactY: Number = cueToTargetY - 25.2 * targetToPocketY;
                var cueToImpactDistance: Number = Math.sqrt(cueToImpactX * cueToImpactX + cueToImpactY * cueToImpactY);

                norm = 1 / cueToImpactDistance;
                cueToImpactX *= norm;
                cueToImpactY *= norm;
                
                var deflectAngleCos: Number = cueToImpactX * targetToPocketX + cueToImpactY * targetToPocketY;
                var deflectAngleScore: Number = _getDeflectionAngleScore(deflectAngleCos);

                if (deflectAngleScore === 0)
                    continue;
                
                // Check for any obstructing balls in the path between the cue ball and the target.
                // (No score is assigned here, just rule out shot candidates with cue-to-target obstructions)
                if (_getNearestBallDistanceToPath(cueBall.x, cueBall.y, cueToImpactX, cueToImpactY, cueToImpactDistance + 25.2, targetBall, cueBall) <= 25.2)
                    continue;
                
                // Calculate the minimum shot speed required to hit the ball into the pocket.
                // Assign a score based on this value.
                // Use e=0.8 from game engine, so 2/(1+e) = 1.11111111111111
                var shotSpeed: Number = _estimateRequiredSpeed(
                    cueToImpactDistance,
                    (1.11111111111111 * requiredTargetSpeed) / deflectAngleCos
                );

                if (shotSpeed < 0.25)
                    shotSpeed = 0.25;   // Keep minimum shot speed at 0.25

                var shotSpeedScore: Number = _getShotSpeedScore(shotSpeed);
                if (shotSpeedScore === 0)
                    continue;

                if (shotSpeed > 1.67)
                    shotSpeed = 1.67;
                
                // The shot candidate must be evaluated at different speeds (above the minimum) to determine
                // the optimal shot speed. Create a maximum of 10 candidates with shot speeds equally spaced
                // between the minimum required and maximum possible, subject to a minimum step of 0.1.
                var speedStep: Number = (1.67 - shotSpeed) * 0.1;
                if (speedStep < 0.1)
                    speedStep = 0.1;
                    
                while (true) {
                    var shotCandidate: CPUPlayerShotCandidate = _makeNewShotCandidate();

                    shotCandidate.targetBall = targetBall;
                    shotCandidate.impactX = cueBall.x + cueToImpactX * cueToImpactDistance;
                    shotCandidate.impactY = cueBall.y + cueToImpactY * cueToImpactDistance;
                    shotCandidate.targetDirX = targetToPocketX;
                    shotCandidate.targetDirY = targetToPocketY;
                    shotCandidate.shotDirX = cueToImpactX;
                    shotCandidate.shotDirY = cueToImpactY;
                    shotCandidate.shotSpeed = shotSpeed;
                    
                    // For each individual candidate, determine some additional parameters such as
                    // the cue ball's final position which is speed dependent.
                    
                    var impactSpeed: Number = _estimateFinalSpeed(cueToImpactDistance, shotSpeed);

                    // (1+e)/2 = 0.9
                    var normalImpactDV: Number = -0.9 * impactSpeed * (cueToImpactX * targetToPocketX + cueToImpactY * targetToPocketY);
                    
                    var cuePostImpactVX: Number = impactSpeed * cueToImpactX + normalImpactDV * targetToPocketX;
                    var cuePostImpactVY: Number = impactSpeed * cueToImpactY + normalImpactDV * targetToPocketY;
                    var cuePostImpactSpeed: Number = Math.sqrt(cuePostImpactVX * cuePostImpactVX + cuePostImpactVY * cuePostImpactVY);
                    
                    norm = 1 / cuePostImpactSpeed;
                    cuePostImpactVX *= norm;
                    cuePostImpactVY *= norm;
                    
                    // Calculate a score based on whether the cue ball would be potted after hitting
                    // the target ball.

                    var cueBallStopDistance: Number = _estimateStoppingDistance(cuePostImpactSpeed);
                    var cueBallPotScore: Number = _getCueBallPocketEntryScore(
                        shotCandidate.impactX, shotCandidate.impactY, cuePostImpactVX, cuePostImpactVY, cueBallStopDistance, targetBall);
                    
                    if (cueBallPotScore !== 1) {
                        shotCandidate.postImpactCueBallState = 1;
                    }
                    else {
                        shotCandidate.cueBallStopX = shotCandidate.impactX + cueBallStopDistance * cuePostImpactVX;
                        shotCandidate.cueBallStopY = shotCandidate.impactY + cueBallStopDistance * cuePostImpactVY;

                        // Now determine whether the cue ball would stop at the expected final position without colliding
                        // with a cushion or another ball.
                        // [Note that I have deliberately used somewhat weak conditions here]
                        if (shotCandidate.cueBallStopX < -15
                            || shotCandidate.cueBallStopX > 1728.4
                            || shotCandidate.cueBallStopY < -15
                            || shotCandidate.cueBallStopY > 868.4)
                        {
                            shotCandidate.postImpactCueBallState = 2;
                        }
                        else {
                            var ballDistance: Number = _getNearestBallDistanceToPath(
                                shotCandidate.impactX,
                                shotCandidate.impactY,
                                cuePostImpactVX,
                                cuePostImpactVY,
                                cueBallStopDistance,
                                targetBall,
                                cueBall
                            );
                            shotCandidate.postImpactCueBallState = (ballDistance < 23.2) ? 2 : 0;
                        }
                    }

                    // Set the shot candidate's overall score (for now) as the product of the four scores evaluated.
                    // Additional scoring, such as that based on the target ball's colour and the shots available
                    // at the cue ball's final position, will be done later.
                    shotCandidate.score = targetPathScore * targetDistanceScore * shotSpeedScore * deflectAngleScore * cueBallPotScore;
                    
                    if (shotSpeed === 1.67)
                        break;

                    shotSpeed += speedStep;
                    if (shotSpeed > 1.67)
                        shotSpeed = 1.67;
                } 
            }
        }
        
        /**
         * Creates second and fourth-round shot candidates for the given target ball.
         * 
         * @param targetBall The target ball.
         */
        private function _createRound2and4ShotCandidates(targetBall: Ball): void {
            var cueBall: Ball = m_engine.balls[0];
            var cueToTargetX: Number = targetBall.x - cueBall.x;
            var cueToTargetY: Number = targetBall.y - cueBall.y;
            var cueToTargetDistance: Number = Math.sqrt(cueToTargetX * cueToTargetX + cueToTargetY * cueToTargetY);

            var norm: Number = 1 / cueToTargetDistance;
            cueToTargetX *= norm;
            cueToTargetY *= norm;
            
            // Check for obstructions between the cue ball and the target.
            // Note that in this round the 'no obstruction' rule has some exceptions for red balls - hits at
            // them are allowed of they are obstructed only by other red balls which are within a threshold
            // distance of the target (currently set at 45). This is done so that the CPU can hit at a tightly
            // packed cluster of reds (required for breaking the red rack at the start of the game)
            var obstructionDistance: Number = _getNearestBallDistanceToPath(
                cueBall.x,
                cueBall.y,
                cueToTargetX,
                cueToTargetY,
                cueToTargetDistance,
                targetBall,
                cueBall,
                null,
                (targetBall.colour === 1) ? 1 : -1,
                45
            );
            if (obstructionDistance <= 25.2)
                return;
            
            // In this round the cue ball is always shot at maximum speed.
            var requiredSpeed: Number = _estimateRequiredSpeed(cueToTargetDistance, 0.02);
            if (requiredSpeed > 1.67)
                return;
            
            var shotCandidate: CPUPlayerShotCandidate = _makeNewShotCandidate();
            shotCandidate.targetBall = targetBall;
            shotCandidate.impactX = cueBall.x + cueToTargetY * (cueToTargetDistance - 25.2);
            shotCandidate.impactY = cueBall.y + cueToTargetY * (cueToTargetDistance - 25.2);
            shotCandidate.targetDirX = cueToTargetX;
            shotCandidate.targetDirY = cueToTargetY;
            shotCandidate.shotSpeed = 1.67;
            shotCandidate.shotDirX = cueToTargetX;
            shotCandidate.shotDirY = cueToTargetY;
            shotCandidate.score = 1;
            
            // Here there is no interest in knowing the final position of the cue ball after collision
            // (at least for now) so set the postImpactCueBallState value to 2 (not determined)
            shotCandidate.postImpactCueBallState = 2;
        }
        
        /**
         * Creates third-round shot candidates for the given target ball.
         * 
         * @param targetBall The target ball.
         */
        private function _createRound3ShotCandidates(targetBall: Ball): void {
            var cueBall: Ball = m_engine.balls[0];
            var cushions: Vector.<Cushion> = GameEngine.cushions;
            
            for (var i: int = 0, n: int = cushions.length; i < n; i++) {                
                var cushion: Cushion = cushions[i];

                var nx: Number = cushion.normals[2],
                    ny: Number = cushion.normals[3],
                    x1: Number = cushion.points[2],
                    y1: Number = cushion.points[3],
                    x2: Number = cushion.points[4],
                    y2: Number = cushion.points[5];

                var railLength: Number = Math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
                
                // To determine the impact point of the cue ball on the cushion rail, the coordinates
                // of the positions of the cue ball and target ball must be calculated along the tangent
                // and normal to the cushion rail. These coordinates are stored as (a1, a2) for cue ball
                // and (b1, b2) for target ball. (The ball radius is subtracted from the normal
                // coordinates so that the point of impact of the cue ball on the cushion would have
                // a zero normal coordinate)

                var a1: Number = (cueBall.x - x1) * ny - (cueBall.y - y1) * nx;
                var a2: Number = (cueBall.x - x1) * nx + (cueBall.y - y1) * ny - 12.6;
                var b1: Number = (targetBall.x - x1) * ny - (targetBall.y - y1) * nx;
                var b2: Number = (targetBall.x - x1) * nx + (targetBall.y - y1) * ny - 12.6;

                if (a2 < 0.1 || b2 < 0.1) {
                    // Do not consider the shot if either the cue ball or target ball is (almost) touching
                    // the cushion.
                    continue;
                }
                    
                // Calculate c1, the tangent coordinate of the point of impact. Check that it lies on the rail.
                // Use the value of e=0.87 from the game engine.
                var c1: Number = (0.87 * b1 * a2 + b2 * a1) / (0.87 * a2 + b2);
                if (Math.abs(c1) > railLength || c1 * ((x2 - x1) * ny - (y2 - y1) * nx) < 0)
                    continue;
                    
                // From the value of c1, calculate the distance and direction vector between the cue ball's initial
                // position and the point of impact on the cushion, and from the point of impact to the target ball.

                var cueToCushionX: Number = x1 + c1 * ny + 12.6 * nx - cueBall.x;
                var cueToCushionY: Number = y1 - c1 * nx + 12.6 * ny - cueBall.y;
                var cueToCushionDistance: Number = Math.sqrt(
                    cueToCushionX * cueToCushionX + cueToCushionY * cueToCushionY
                );

                var cushionToTargetX: Number = targetBall.x - cueBall.x - cueToCushionX;
                var cushionToTargetY: Number = targetBall.y - cueBall.y - cueToCushionY;
                var cushionToTargetDistance: Number = Math.sqrt(
                    cushionToTargetX * cushionToTargetX + cushionToTargetY * cushionToTargetY
                );
                
                var norm: Number;
                norm = 1 / cueToCushionDistance;
                cueToCushionX *= norm;
                cueToCushionY *= norm;
                norm = 1 / cushionToTargetDistance;
                cushionToTargetX *= norm;
                cushionToTargetY *= norm;
                
                // Check for obstructions in the path from the cue ball to the cushion impact point as well as in
                // the path from there to the target ball.
                if (_getNearestBallDistanceToPath(
                        cueBall.x, cueBall.y, cueToCushionX, cueToCushionY, cueToCushionDistance + 25.2, cueBall
                    ) <= 25.2)
                {
                    continue;
                }

                if (_getNearestBallDistanceToPath(
                        cueBall.x + cueToCushionX * cueToCushionDistance,
                        cueBall.y + cueToCushionY * cueToCushionDistance,
                        cushionToTargetX,
                        cushionToTargetY,
                        cushionToTargetDistance + 25.2,
                        targetBall,
                        cueBall
                    ) <= 25.2)
                {
                    continue;
                }
                
                // Like the second round, for shot candidates in this round the cue ball is struck at maximum
                // speed. Determine whether it would reach the target ball.

                var cushionImpactSpeed: Number = _estimateFinalSpeed(cueToCushionDistance, 1.67);
                if (cushionImpactSpeed <= 0)
                    continue;

                var cushionImpactV1: Number = cushionImpactSpeed * (cueToCushionX * ny - cueToCushionY * nx);
                var cushionImpactV2: Number = cushionImpactSpeed * (cueToCushionX * nx + cueToCushionY * ny);

                // e^2=0.7569
                var targetImpactSpeed: Number = _estimateFinalSpeed(
                    cushionToTargetDistance - 25.2,
                    Math.sqrt(cushionImpactV1 * cushionImpactV1 + 0.7569 * cushionImpactV2 * cushionImpactV2)
                );

                if (targetImpactSpeed <= 0)
                    continue;
                
                var shotCandidate: CPUPlayerShotCandidate = _makeNewShotCandidate();
                shotCandidate.targetBall = targetBall;
                shotCandidate.impactX = targetBall.x - cushionToTargetX * 25.2;
                shotCandidate.impactY = targetBall.y - cushionToTargetY * 25.2;
                shotCandidate.targetDirX = cushionToTargetX;
                shotCandidate.targetDirY = cushionToTargetY;
                shotCandidate.shotSpeed = 1.67;
                shotCandidate.shotDirX = cueToCushionX;
                shotCandidate.shotDirY = cueToCushionY;
                shotCandidate.score = 1;
                
                // Again, no evaluation for future shots on the final cue ball position, so set
                // postImpactCueBallState to 2 (not determined)
                shotCandidate.postImpactCueBallState = 2;
            }
        }
        
        /**
         * Applies scores to the shot candidates based on possible future shots from the cue ball's
         * final position, if determined.
         */
        private function _applyFutureShotScores(): void {
            var balls: Vector.<Ball> = m_engine.balls;
            var cueBall: Ball = balls[0];
            var pocketCentres: Vector.<Number> = GameEngine.pocketCentres;
            var shotCandidates: Vector.<CPUPlayerShotCandidate> = m_shotCandidates;
            var ballCount: int = m_engine.ballsOnTableCount;
            var shotCandidateCount: int = m_shotCandidateCount;
            var pocketCount: int = pocketCentres.length >> 1;

            var candidate: CPUPlayerShotCandidate;
            var futureShotTargets: Vector.<Ball>;
            var fstCount: int;

            var norm: Number;
            var i1: int, i2: int, i3: int, i4: int;
            
            // Determine the target colour of the next shot.
            // Use the value -1 if the colour is to be chosen (after potting a red)
            var nextColour: int;

            if (m_engine.gameState === GameState.CHOOSE_COLOUR) {
                // After potting a colour, the next shot must pot a red.
                // Except when all reds have been potted, in which case the next colour is yellow.
                nextColour = (m_engine.ballsOnTableCount === 7) ? 2 : 1;
            }
            else if (m_engine.currentColour === 1) {
                nextColour = -1;
            }
            else if (m_engine.currentColour === 7) {
                // After the final black is potted it's game over, so future-shot scores are meaningless.
                return;
            }
            else {
                nextColour = m_engine.currentColour + 1;
            }
                
            for (i1 = 1; i1 < ballCount; i1++) {
                var targetBall: Ball = balls[i1];

                if ((nextColour === -1) ? targetBall.colour === 1 : targetBall.colour !== nextColour)
                    continue;
                
                for (i2 = 0; i2 < pocketCount; i2++) {
                    // Check for obstructions in the path from the target to the pocket.
                    // Assign scores based on path obstructions and the distance between the ball and
                    // the pocket (the _getTargetToPocketDistanceScore and _getTargetPathScore functions,
                    // the same ones used in evaluation of the shot candidates, are used for this purpose).
                    
                    var targetToPocketX: Number = pocketCentres[int(i2 << 1)] - targetBall.x;
                    var targetToPocketY: Number = pocketCentres[int((i2 << 1) + 1)] - targetBall.y;
                    var targetToPocketDistance: Number = Math.sqrt(targetToPocketX * targetToPocketX + targetToPocketY * targetToPocketY);
                    
                    norm = 1 / targetToPocketDistance;
                    targetToPocketX *= norm;
                    targetToPocketY *= norm;
                    
                    var distanceScore: Number = _getTargetToPocketDistanceScore(targetToPocketDistance);
                    var pathScore1: Number = _getTargetPathScore(
                        _getNearestBallDistanceToPath(
                            targetBall.x,
                            targetBall.y,
                            targetToPocketX,
                            targetToPocketY,
                            targetToPocketDistance,
                            targetBall,
                            cueBall
                        )
                    );

                    if (pathScore1 === 0)
                        continue;
                        
                    // If there are no obvious obstacles in the ball-pocket path (pathScore1 !== 0) then
                    // check each shot candidate whose final cue ball position has been determined, for whether
                    // this can be a potential candidate for the next shot.
                        
                    for (i3 = 0; i3 < shotCandidateCount; i3++) {
                        candidate = shotCandidates[i3];
                        if (candidate.postImpactCueBallState !== 0) {
                            // Final cue ball position could not be determined, or the cue ball ended up inside
                            // a pocket.
                            continue;
                        }
                         
                        var cueToImpactX: Number = targetBall.x - candidate.cueBallStopX - 25.2 * targetToPocketX;
                        var cueToImpactY: Number = targetBall.y - candidate.cueBallStopY - 25.2 * targetToPocketY;
                        var cueToImpactDistance: Number = Math.sqrt(cueToImpactX * cueToImpactX + cueToImpactY * cueToImpactY);

                        norm = 1 / cueToImpactDistance;
                        cueToImpactX *= norm;
                        cueToImpactY *= norm;
                        
                        // Use the _getTargetPathScore function to calculate the score based on obstructions in
                        // the path from the cue ball to the impact point.
                        var pathScore2: Number = _getTargetPathScore(
                            _getNearestBallDistanceToPath(
                                candidate.cueBallStopX,
                                candidate.cueBallStopY,
                                cueToImpactX,
                                cueToImpactY,
                                cueToImpactDistance + 25.2,
                                targetBall,
                                candidate.targetBall,
                                cueBall
                            )
                        );

                        if (pathScore2 === 0)
                            continue;
                        
                        // Scores based on the minimum required shot speed will not be considered here as
                        // finding the minimum speed is a computationally expensive operation. Instead, a
                        // stricter deflection angle scoring is used (instead of using the _getDeflectionAngleScore
                        // function used in the evalutation of the candidates)
                            
                        var cosTheta: Number = cueToImpactX * targetToPocketX + cueToImpactY * targetToPocketY;
                        var angleScore: Number;
                        if (cosTheta >= 0.965926)        // 15 deg
                            angleScore = 1.00;
                        else if (cosTheta >= 0.866025)   // 30 deg
                            angleScore = 0.90;
                        else if (cosTheta >= 0.707107)   // 45 deg
                            angleScore = 0.75;
                        else if (cosTheta >= 0.5)        // 60 deg
                            angleScore = 0.45;
                        else
                            continue;
                        
                        var totalScore: Number = pathScore1 * pathScore2 * angleScore * distanceScore;
                        
                        if (nextColour === 1 && candidate.futureShotTargets.length < 4) {
                            // If the target colour is red: Store the target ball (Ball object) for each
                            // future shot (upto 4) in the shot candidate object's futureShotTargets vector if
                            // it does not already exist.
                            // Based on this, a score can be calculated at the end based on the number of red
                            // target balls that can be hit.
                            futureShotTargets = candidate.futureShotTargets;
                            fstCount = futureShotTargets.length;
                            for (i4 = 0; i4 < fstCount; i4++) {
                                if (targetBall === futureShotTargets[i4])
                                    break;
                            }
                            if (i4 === fstCount)
                                futureShotTargets[i4] = targetBall;
                        }

                        if (nextColour === -1) {
                            // If the target colour it to be chosen, apply a score based on the value of
                            // the target ball. (The current scores are 1.80 for black, 1.55 for pink and
                            // 1.35 for blue/brown)
                            if (targetBall.colour === 7)
                                totalScore *= 1.80;
                            else if (targetBall.colour === 6)
                                totalScore *= 1.55;
                            else if (targetBall.colour === 5 || targetBall.colour === 4)
                                totalScore *= 1.35;
                        }
                        
                        // Update the candidate's futureShotBestScore field.
                        if (candidate.futureShotBestScore < totalScore)
                            candidate.futureShotBestScore = totalScore;
                    }
                }
            }
            
            // The futureShotFactor is a value which determines the contribution of the future shot
            // score to the overall score.
            var futureShotFactor: Number = (nextColour === -1) ? 0.4 : 0.25;
            
            for (i1 = 0; i1 < shotCandidateCount; i1++) {
                candidate = shotCandidates[i1];
                if (nextColour === 1) {
                    // Apply the score based on the number of red targets.
                    fstCount = candidate.futureShotTargets.length;
                    if (fstCount >= 4)
                        candidate.futureShotBestScore *= 1.60;
                    else if (fstCount === 3)
                        candidate.futureShotBestScore *= 1.45;
                    else if (fstCount === 2)
                        candidate.futureShotBestScore *= 1.30;
                }
                
                // Apply the future shot score to the candidate's total score.
                candidate.score *= 1 + futureShotFactor * candidate.futureShotBestScore;
            }
        }
        
    }

}