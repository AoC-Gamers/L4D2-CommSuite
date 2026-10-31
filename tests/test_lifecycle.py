"""Execute productive dependency transitions without loading SourceMod."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'addons/sourcemod/scripting'


def function(source,name):
    match=re.search(r'(?:public |static )?\w+ '+name+r'\([^)]*\)\s*\{',source)
    if not match:return ''
    end,depth=match.end(),1
    while depth:
        depth+=(source[end]=='{')-(source[end]=='}');end+=1
    return source[match.start():end].replace('public ','').replace('static ','').replace('const char[]','const char*')


def run(code):
    with tempfile.TemporaryDirectory(prefix='commsuite-lifecycle-') as directory:
        cpp,binary=Path(directory)/'test.cpp',Path(directory)/'test';cpp.write_text(code)
        subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror',
                        '-fsanitize=address,undefined','-fno-pie','-no-pie',str(cpp),'-o',str(binary)],check=True)
        subprocess.run([str(binary)],check=True)


HEADER=r'''
#include <cassert>
#include <cstring>
constexpr char L4D2_COMMCORE_LIBRARY[]="core",L4D2_COMMGUARD_LIBRARY[]="guard";
constexpr char L4D2_COMMSUITE_BASECOMM_LIBRARY[]="base",L4D2_COMMSUITE_BANSYSTEM_COMM_LIBRARY[]="bansystem",L4D2_COMMSUITE_SOURCECOMMS_LIBRARY[]="source";
bool base=true,bansystem=true,source=true,nativesBound=false;int queries=0,lastProvider=-1,queued=0;
bool LibraryExists(const char*s){if(!strcmp(s,"base"))return base;if(!strcmp(s,"source"))return source;if(!strcmp(s,"bansystem"))return bansystem;return true;}
bool StrEqual(const char*a,const char*b){return !strcmp(a,b);}
using L4D2CommGuardProvider=int;constexpr int Provider_None=0,Provider_BaseComm=1,Provider_SourceComms=2,Provider_BanSystemComm=4;
'''


def guard_program(src):
    state=re.search(r'enum struct CommGuardRuntimeState\s*\{.*?\n\}',src,re.S)
    if state:
        state=state[0].replace('enum struct','struct').replace('this.','this->').replace('const char[]','const char*')+';\nCommGuardRuntimeState g_Runtime;'
    else:
        state='bool g_bCoreLibrary=false,g_bBaseCommLibrary=false,g_bBanSystemCommLibrary=false,g_bSourceCommsLibrary=false;'
    names=['L4D2CommGuard_GetActiveProviderInternal','OnLibraryAdded','OnLibraryRemoved']
    if 'CommGuardRuntimeState' in src:names+=['OnAllPluginsLoaded','OnGameFrame']
    bodies=[function(src,n) for n in names]
    prototypes='\n'.join(b.split('{')[0]+';' for b in bodies)
    shims=r'''
void L4D2CommGuard_SyncProviderState(){}
void L4D2CommGuard_RefreshAllVoiceStates(){lastProvider=L4D2CommGuard_GetActiveProviderInternal();if(lastProvider){assert(nativesBound);queries++;}}
'''
    if not state.startswith('struct'):
        main='int main(){OnLibraryAdded("bansystem");assert(queries==0);}'
    else:
        main=r'''
int main(){g_Runtime.Reset();OnGameFrame();assert(queries==0);OnAllPluginsLoaded();assert(queries==0);
 nativesBound=true;OnGameFrame();assert(queries==1&&lastProvider==Provider_BanSystemComm);
 g_Runtime.needsVoiceSync=false;OnLibraryAdded("unrelated");assert(!g_Runtime.needsVoiceSync);
 OnLibraryRemoved("bansystem");OnLibraryAdded("bansystem");assert(queries==1);OnGameFrame();assert(queries==2&&lastProvider==4);
 OnLibraryRemoved("bansystem");OnGameFrame();assert(lastProvider==2);
 OnLibraryRemoved("source");OnGameFrame();assert(lastProvider==1);
 OnLibraryRemoved("base");OnGameFrame();assert(lastProvider==0);
 nativesBound=false;g_Runtime.Reset();OnAllPluginsLoaded();assert(queries==4); // Reload inventories without calling natives.
 nativesBound=true;OnGameFrame();assert(lastProvider==4&&queries==5);
}
'''
    return HEADER+state+prototypes+shims+'\n'.join(bodies)+main


class LifecycleTests(unittest.TestCase):
    def test_guard_defers_queries_and_preserves_provider_priority(self):
        src=(BASE/'l4d2_commguard.sp').read_text()
        self.assertNotIn('RefreshAllVoiceStates',function(src,'OnPluginStart'))
        run(guard_program(src))

    def test_relay_defers_cookie_initialization_voice_query(self):
        src=(BASE/'l4d2_commrelay.sp').read_text()
        state=re.search(r'enum struct CommRelayRuntimeState\s*\{.*?\n\}',src,re.S)[0]
        state=state.replace('enum struct','struct').replace('this.','this->').replace('const char[]','const char*')+';\nCommRelayRuntimeState g_Runtime;'
        names=['OnAllPluginsLoaded','OnLibraryAdded','OnLibraryRemoved','OnGameFrame','RefreshClientVoiceOverrides']
        bodies=[function(src,n) for n in names]
        bodies=[b.replace('null','nullptr').replace('g_cvVoiceEnabled.BoolValue','g_cvVoiceEnabled->BoolValue') for b in bodies]
        prototypes='\n'.join(b.split('{')[0]+';' for b in bodies)
        run(HEADER+state+r'''
using ListenOverride=int;using L4DTeam=int;
constexpr int Listen_Default=0,Listen_No=1,Listen_Yes=2,L4DTeam_Survivor=2,L4DTeam_Infected=3,MaxClients=2;
struct Cvar{bool BoolValue=true;}cv;Cvar*g_cvVoiceEnabled=&cv;
bool g_bVoiceEnabledByClient[3]={false,true,true},blocked=true;
int overrides[3][3]{};
bool IsHumanClient(int c){return c>0&&c<=2;}bool IsHumanSpectator(int c){return c==1;}
int L4D_GetClientTeam(int c){return c==1?1:L4DTeam_Survivor;}
bool IsVoiceRelayTeamEnabled(int){return true;}
bool L4D2CommGuard_IsClientVoiceBlocked(int){assert(nativesBound);queries++;return blocked;}
int GetListenOverride(int r,int s){return overrides[r][s];}
void SetListenOverride(int r,int s,int value){overrides[r][s]=value;}
void QueueRefreshAllVoiceOverrides(){queued++;}
constexpr int Debug_Voice=4;void Relay_LogFormatted(int,const char*,const char*,...){}
'''+prototypes+'\n'.join(bodies)+r'''
int main(){g_Runtime.Reset();RefreshClientVoiceOverrides(1);assert(queries==0);
 OnAllPluginsLoaded();assert(queries==0);nativesBound=true;RefreshClientVoiceOverrides(1);assert(overrides[1][2]==Listen_No);
 blocked=false;RefreshClientVoiceOverrides(1);assert(overrides[1][2]==Listen_Yes);
 int count=queries;OnLibraryRemoved("guard");assert(queries==count);OnGameFrame();assert(queued>0);
 RefreshClientVoiceOverrides(1);assert(queries==count);OnLibraryAdded("guard");OnGameFrame();
 blocked=true;RefreshClientVoiceOverrides(1);assert(overrides[1][2]==Listen_No);
 g_bVoiceEnabledByClient[1]=false;count=queries;RefreshClientVoiceOverrides(1);assert(queries==count&&overrides[1][2]==Listen_No);
}
''')
