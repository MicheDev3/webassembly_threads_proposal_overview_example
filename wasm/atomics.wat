(module
  	;; Import 1 page (64Kib) of shared memory.
  	(import "env" "memory" (memory 1 1 shared))
  	
  	;; TODO: These are functions now, so that it is easier
  	;; Inline these in the future though
  	;;(
  	(func $wait
  		(param $address i32)
  		(param $value   i32) ;; value to wait for
  		(param $timeout i64) ;; $timeout=-1 => infinite timeout
  		(result i32)
			;; Wait for the address. memory.atomic.wait32 returns:
			;;   0 => "ok", woken by another agent.
			;;   1 => "not-equal", loaded value != expected value
			;;   2 => "timed-out", the timeout expired
  			(memory.atomic.wait32
	        	(local.get $address)
	          	(local.get $value)
	          	(local.get $timeout)
          	)
  	)
  	
  	(func $notify
  		(param $address i32)
  		(param $value   i32) ;; number of waiters to wake
  		(result i32)
			;; Notify waiters. memory.atomic.notify returns
			;; the numbers of waiters woken
			(memory.atomic.notify
	        	(local.get $address)
	        	(local.get $value)
	        )
  	)
  	;;)

  	;; Wake thread for work
  	(func (export "wake")
  		(param $address i32)
  			(drop
				(i32.atomic.rmw.add
  					(local.get $address)
  					(i32.const 1)
  				)
  			)
  			
  			(drop
				(call $notify
		        	(local.get $address)
		        	(i32.const 1)
		        )
	        )
  	)
  	
  	;; Wait thread for work
  	(func (export "wait")
  		(param $address i32)
  			(drop
				(i32.atomic.rmw.sub
  					(local.get $address)
  					(i32.const 1)
  				)
  			)
  			
	        (drop
	        	(call $wait 
	        		(local.get $address)
	        		(i32.const  0)
	        		(i64.const -1)
	        	)
	    	)
  	)
  	

  	;; Lock a mutex at the given address, retrying until successful.
  	(func (export "lock") 
  		(param $address i32)
	    	(block $done
	      		(loop $retry
      			    ;; Attempt locking. atomic.rmw.cmpxchg works as follow:
				    ;; - Loads the value at $address.
				    ;; - If it is 0 (unlocked), set it to 1 (locked).
				    ;; - Return the originally loaded value.
				    ;;(
				    	(i32.atomic.rmw.cmpxchg
				      		(local.get $address)
		    		  		(i32.const  0) ;; expected value    (0 => unlocked)
		      				(i32.const  1) ;; replacement value (1 => locked  )
		  				)
	  				    ;; Negates the loaded value to have:
	  				    ;; - If 0 => 1, meaning lock     acquired
	  				    ;; - If 1 => 0, meaning lock NOT acquired
						(i32.eqz)
					;;)
					
					;; Breaks if lock acquired
	        		(br_if $done)

					;; We do not care about the result so we drop it
			        (drop
			        	(call $wait 
			        		(local.get $address)
			        		(i32.const  0)
			        		(i64.const -1)
			        	)
		        	)
					
					;; Try to acquire the lock again.
		        	(br $retry)
	      		)
	    	)
  	)

	;; Unlock a mutex at the given address.
  	(func (export "unlock")
    	(param $address i32)
    		;; Unlock the address by storing 0.
		    (i32.atomic.store
		      	(local.get $address)
		      	(i32.const 0)
	      	)
		
			;; We do not care about the result so we drop it
		    (drop
				(call $notify
		        	(local.get $address)
		        	(i32.const 1)
		        )
	        )
  	)
)