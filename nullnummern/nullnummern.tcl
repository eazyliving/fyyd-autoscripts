source /opt/auto/tcl-support/json.tcl

set curl "curl -s"
set curation_id_de 0
set curation_id_en 0

set accesstoken <TAKE_THIS_FROM_YOUR_DEV_PAGE>
set latest [::json::parse [eval exec $curl "https://api.fyyd.de/0.2/podcast/latest?count=10"] 1]

dict for {key podcast} [dict get $latest data] {
	
	if {[dict get $podcast language]=="de"} {
		lappend pids [dict get $podcast id]
		lappend pids $curation_id_de
	}

	if {[dict get $podcast language]=="en"} {
		lappend pids [dict get $podcast id]
		lappend pids $curation_id_en
	}

}

foreach {pid cid} $pids {

	puts "$pid: $cid"
	set episodes [::json::parse [eval exec $curl "https://api.fyyd.de/0.2/podcast/episodes?podcast_id=$pid&count=15"] 1]
	set eids {}
	
	dict for {key episode} [dict get $episodes data episodes] {
		lappend eids [list [dict get $episode id] [clock scan [lindex [split [dict get $episode pubdate] \+] 0]]]
	}
	
	if {[llength $eids]<10} {

		set eid [lindex [lsort -integer -increasing -index 1 $eids] 0 0]
		
		# NULLNUMMER!
		set ret [eval exec curl -s -H \"Authorization: Bearer $accesstoken\" \"https://api.fyyd.de/0.2/curate\" --data \"curation_id=$cid&episode_id=$eid&force_state=1\"]

    }

}


