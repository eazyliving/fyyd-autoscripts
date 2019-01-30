tcl::tm::path add /opt/auto/tcl-support/feedparser
package require feedparser

source /opt/auto/tcl-support/json.tcl

set curl "curl -s"

# You need to change those values

set curation_id 0000 
set accesstoken_fyyd <TAKE_THIS_FROM_YOUR_DEV_PAGE>
set accesstoken_mastodon <TAKE_THIS_FROM_MASTODONS_DEV_PAGE>
set instance chaos.social

# stop here :)

set url_timeline [format "https://%s/api/v1/timelines/home" $instance]
set eids {}


# Add whatever you think might fit to this blacklist
# the pattern has to match the link found

set blacklist {

	*chaos.social*
	*mastodon.at*
	*mastodon.social*
	*/tags/*

}


set prev_file [file join [file dirname [info script]] .min_id]

if {![file exists $prev_file]} {
	set min_id 0
} else {
	set min_id [eval exec cat $prev_file]
}

set json ""
set ids {} 

proc inBlacklist {link} {


	global blacklist
	
	foreach black $blacklist {
		if {[string match $black $link]} {
			return 1
		}
	}
	return 0
}


proc findHREFS {parent} {
	
	set hrefs ""
	
	set type [$parent nodeType]
  		
	if {[$parent nodeName]=="a"} {
			lappend hrefs [$parent getAttribute href]

	}  else {
		foreach child [$parent childNodes] {
			lappend hrefs [findHREFS $child]
		}
	}
	regsub -all "\{\}" $hrefs "" hrefs
	set hrefs [string trim $hrefs]
	return [join $hrefs ]
	
}	

while {1} {
	
	if {$min_id==0} {
		set json [eval exec curl -s -H \"Authorization: Bearer $accesstoken_mastodon\" $url_timeline]
	} else {
		set json [eval exec curl -s -H \"Authorization: Bearer $accesstoken_mastodon\" [format "%s?min_id=%d" $url_timeline $min_id]]
	}
	
	
	if {$json=={[]}} {
		break
	}
	
	set timeline [::json::parse $json 1]

	dict for {key entry} $timeline {
		lappend ids [dict get $entry id]
		set content [string trim [dict get $entry content]]

		if {[string length $content]==0} {
			continue
		}
		set doc [dom parse -html "<html>$content</html>"]

		foreach p [$doc childNodes] {
			set links [findHREFS $p]
		
			if {[llength $links]==0} {
				continue
			}
			
			foreach link $links {

				if {[inBlacklist $link]} {
					continue
				}
				set eid 0
				set episodes [::json::parse [eval exec curl -s "https://api.fyyd.de/0.2/search/episode?url=$link"] 1]

				dict for {key episode} [dict get $episodes data] {
				
					set eid [dict get $episode id] 
					
					break
				}
				
				if {$eid!=0} {
					lappend eids $eid
				}


			
			}
			
		}
		
	
	}
	
	if {[llength $ids]!=0} {
		set min_id [lindex [lsort -decreasing $ids] 0]
		incr min_id
		eval exec echo $min_id > $prev_file
	}
	
	set ids {}
}

foreach eid [lsort -uniq $eids] {

	set ret [eval exec curl -s -H \"Authorization: Bearer $accesstoken_fyyd\" \"https://api.fyyd.de/0.2/curate\" --data \"curation_id=$curation_id&episode_id=$eid&force_state=1\"]

}
