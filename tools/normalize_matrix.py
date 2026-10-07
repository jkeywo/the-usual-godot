"""Normalize independently exported baseline state without running Godot.
Generate raw files by appending reference_matrix.rs to the isolated baseline tests,
then run export_godot_matrix with GODOT_FIXTURES pointing at .reference/matrix.
"""
from pathlib import Path
import json
from convert_reference import Ron, normalize
ROOT = Path(__file__).resolve().parents[1]
BANDS = {'Autonomous':0, 'Player':1000, 'Urgent':2000, 'Mandatory':3000}

def events(items):
    return [{'tick':e['tick'],'kind':e['kind']['kind'],'data':e['kind'].get('value',{})} for e in items]

def canonical(r):
    result = {'tick':r['tick'], 'seed':str(r['seed']), 'start':r['start_minute_of_day'], 'next_id':r['next_sim_id']}
    for a,b in [('fired','fired_invitations'),('calling','calling_neighbours'),('knowledge','household_knowledge'),('read_notices','read_notices'),('started','started_coordinators')]:result[a]=r[b]
    for a,b in [('memories','memories'),('moments','moments'),('carrying','carrying'),('quality','cooking_quality'),('tasks','player_tasks'),('roles','role_assignments'),('portals','portal_occupancy')]:result[a]=r[b] or {}
    result['residents']={str(who['id']):{'definition_id':who['definition_id'],'position':who['position'],'needs':{}} for who in r['residents']}
    for who,kind,need in r['needs']:result['residents'][str(who)]['needs'][kind]=need
    result['stocks']={obj:dict(stock) for obj,stock in r['stocks']}
    result['relationships']={f'{who}:{about}':dict(deltas) for who,about,deltas in r['relationships']}
    result['beliefs']={f'{who}:{about}':dict(belief,observer=who) for who,about,topic,belief in r['beliefs']}
    result['commitments']={who:dict(c,active_from=c['active_from']['hour']*60+c['active_from']['minute']) for who,c in dict(r['commitments']).items()}
    result['initiatives']={key:dict(i,spoken=dict(i['spoken'])) for key,i in dict(r['initiatives']).items()}
    result['slots']={f'{obj}/{slot}':who for obj,slot,who in r['object_slot_claims']}
    result['capabilities']={f'{who}/{cap}':obj for who,cap,obj in r['capability_claims']}
    result['plans']={who:dict(p,band=BANDS[p['band']],frames=[{'plan':f['plan'],'step':f['step'],'flight':f['state']=='InFlight'} for f in p['frames']]) for who,p in dict(r['active_plans']).items()}
    result['walks']={}
    for who,w in dict(r['go_to']).items():
        q={k:v for k,v in w.items() if k not in ['next_step','request_age','player_task','band','traversal']}
        q.update(next=w['next_step'],age=w['request_age'],task=w['player_task'] or 0,band=BANDS[w['band']],traversal=w['traversal'] or {})
        if q['traversal']:
            q['traversal']['remaining']=q['traversal'].pop('ticks_remaining')
        result['walks'][who]=q
    result['uses']={who:{'object':u['object'],'affordance':u['affordance'],'slot':u['slot'],'capability':u['capability'],'remaining':u['ticks_remaining'],'task':u['player_task'] or 0} for who,u in dict(r['active_object_uses']).items()}
    result['requests']=r['use_requests']
    result['queues']={who:[dict(q['order']['value'],task=q['task'],kind=q['order']['kind']) for q in queue] for who,queue in dict(r['player_task_queue']).items()}
    result['pending']=events(r['pending_events']); result['ingested']=events(r['ingested_events'])
    return result

if __name__=='__main__':
    names=[]
    for path in sorted((ROOT/'.reference/matrix').glob('*.ron')):
        seed,commands,checkpoints,ledger=normalize(Ron(path.read_text()).value())
        data={'seed':seed,'commands':commands,'checkpoints':[[tick,canonical(state)] for tick,state in checkpoints],'events':events(ledger)}
        target=ROOT/'tests/reference'/path.with_suffix('.json').name
        target.write_text(json.dumps(data,separators=(',',':'))+'\n')
        names.append(target.name)
    (ROOT/'tests/reference/matrix_manifest.json').write_text(json.dumps(names,indent=2)+'\n')
    print(f'Converted {len(names)} independent reference scenarios')
