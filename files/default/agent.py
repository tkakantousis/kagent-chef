#!/usr/bin/env python

'''
Install:
 requests:    easy_install requests
 bottle:      easy_install bottle
 Cherrypy:    easy_install cherrypy
 Netifaces:   easy_install netifaces
 IPy:         easy_install ipy
 pyOpenSSL:   apt-get install python-openssl
 MySQLdb:     apt-get install python-mysqldb
'''

import time
from time import sleep
from datetime import datetime
import multiprocessing
import thread
from threading import Lock
import threading
import Queue
import subprocess
from subprocess import Popen
from subprocess import CalledProcessError
import os
import sys
import ConfigParser
import requests
import logging.handlers
import json
from OpenSSL import crypto
import socket
from os.path import exists, join
import MySQLdb
from bottle import Bottle, run, get, post, request, HTTPResponse, server_names, ServerAdapter, response
from cheroot import wsgi
from cheroot.ssl.builtin import BuiltinSSLAdapter
import netifaces
from IPy import IP
import re
from collections import defaultdict
import io
import tempfile
import argparse

import kagent_utils
from kagent_utils import KConfig
from kagent_utils import IntervalParser
from kagent_utils import UnrecognizedIntervalException

global mysql_process
mysql_process = None
var="~#@#@!#@!#!@#@!#"

config_mutex = Lock()
conda_mutex = Lock()

HTTP_OK = 200

global states
states = {}

global conda_ongoing
conda_ongoing = defaultdict(lambda: False)

cores = multiprocessing.cpu_count()

def count_num_gpus():
    try:
        p = Popen(['which nvidia-smi'], shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        (output,err)=p.communicate()
        returncode = p.wait()
        if not returncode == 0:
            return 0
        process = subprocess.Popen("nvidia-smi -L", shell=True, stdout=subprocess.PIPE)
        stdout_list = process.communicate()[0].split('\n')
        return len(stdout_list)-1
    except Exception as err:
        return 0

# logging
def setupLogging(kconfig):
    try:
        os.remove(kconfig.agent_log_file + '.1')
    except:
        pass
    with open(kconfig.agent_log_file, 'w'):  # clear log file
        pass
    
    global logger
    logger = logging.getLogger('agent')
    logger_formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
    logger_file_handler = logging.handlers.RotatingFileHandler(kconfig.agent_log_file, "w", maxBytes=kconfig.max_log_size, backupCount=1)
    logger_stream_handler = logging.StreamHandler()
    logger_file_handler.setFormatter(logger_formatter)
    logger_stream_handler.setFormatter(logger_formatter)
    logger.addHandler(logger_file_handler)
    logger.addHandler(logger_stream_handler)
    logger.setLevel(kconfig.logging_level)

    # Setup kagent_utils logger
    kagent_utils_logger = logging.getLogger('kagent_utils')
    kagent_utils_logger.setLevel(kconfig.logging_level)
    kagent_utils_logger.addHandler(logger_file_handler)
    kagent_utils_logger.addHandler(logger_stream_handler)

    # Setup csr logger
    csr_logger = logging.getLogger('csr')
    csr_logger.setLevel(kconfig.logging_level)
    csr_logger.addHandler(logger_file_handler)
    csr_logger.addHandler(logger_stream_handler)

    logger.info("Hops-Kagent started.")
    logger.info("Heartbeat URL: {0}".format(kconfig.heartbeat_url))
    logger.info("Alert URL: {0}".format(kconfig.alert_url))
    logger.info("Host Id: {0}".format(kconfig.host_id))
    logger.info("Hostname: {0}".format(kconfig.hostname))
    logger.info("Public IP: {0}".format(kconfig.public_ip))
    logger.info("Private IP: {0}".format(kconfig.private_ip))

# reading services
def readServicesFile():
    try:
        global services
        services = ConfigParser.ConfigParser()
        services.read(kconfig.services_file)

        for s in services.sections():
            if services.has_option(s, "service") :
                states[services.get(s, "service")] = {'status':'Stopped', 'start-time':''}
    except Exception, e:
        print "Error in the services file. Check its formatting: {0}: {1}".format(kconfig.services_file, e)
        logger.error("Exception while reading {0} file: {1}".format(kconfig.services_file, e))
        sys.exit(1)


logged_in = False

# http://stackoverflow.com/questions/12435211/python-threading-timer-repeat-function-every-n-seconds
def setInterval(interval):
    def decorator(function):
        def wrapper(*args, **kwargs):
            stopped = threading.Event()

            def loop(): # executed in another thread
                while not stopped.wait(interval): # until stopped
                    function(*args, **kwargs)

            t = threading.Thread(target=loop)
            t.daemon = True # stop if the program exits
            t.start()
            return stopped
        return wrapper
    return decorator


class Util():

    def logging_level(self, level):
        return {
                'INFO': logging.INFO,
                'WARN': logging.WARN,
                'WARNING': logging.WARNING,
                'ERROR': logging.ERROR,
                'DEBUG' : logging.DEBUG,
                'CRITICAL': logging.CRITICAL,
                }.get(level, logging.NOTSET)

    @staticmethod
    def tail(file_name, n):
        stdin, stdout = os.popen2("tail -n {0} {1}".format(n, file_name))
        stdin.close()
        lines = stdout.readlines();
        stdout.close()
        log = "".join(str(x) for x in lines)
        return log


class Heartbeat():
    daemon_threads = True
    def __init__(self, commands_queue, system_commands_status, system_commands_status_mutex,
                 conda_commands_status, conda_commands_status_mutex, conda_report_interval,
                 conda_envs_monitor_list):
        self._commands_queue = commands_queue
        self._system_commands_status = system_commands_status
        self._system_commands_status_mutex = system_commands_status_mutex
        self._conda_commands_status = conda_commands_status
        self._conda_commands_status_mutex = conda_commands_status_mutex
        self._conda_envs_monitor_list = conda_envs_monitor_list
        # in ms
        self._conda_report_interval = conda_report_interval
        self._last_conda_report = long(time.mktime(datetime.now().timetuple()) * 1000)
            
        while True:
            self.send()
            time.sleep(kconfig.heartbeat_interval)


    @staticmethod
    def login():
        json_headers = {'User-Agent': 'Agent', 'content-type': 'application/json'}
        form_headers = {'User-Agent': 'Agent', 'content-type': 'application/x-www-form-urlencoded'}
        payload = {}
        global logged_in
        global session
        try:
            session = requests.Session()
            resp = session.post(kconfig.login_url, data={'email': kconfig.server_username, 'password': kconfig.server_password}, headers=form_headers, verify=False)
#            resp = session.put(kconfig.register_url, data=json.dumps(payload), headers=json_headers, verify=False)
            if not resp.status_code == HTTP_OK:
                logged_in = False
                logger.warn('Could not login agent to Hopsworks (Status code: {0}).'.format(resp.status_code))
            else:
                logger.info('Successful login of agent to Hopsworks (Status code: {0}).'.format(resp.status_code))
                logged_in = True
        except Exception as err:
            logger.warn('Could not login agent to Hopsworks {0}'.format(err))
            logged_in = False

    @staticmethod
    def serviceKey(*keys):
            global states
            ob = states
            for key in keys:
                ob = ob[key]
            return ob

    def is_conda_gc_triggered(self):
        conda_report = False
        CONDA_CONTROL = '/tmp/trigger_conda_gc'
        if os.path.isfile(CONDA_CONTROL):
            with open(CONDA_CONTROL, 'r') as fd:
                if int(next(fd)) == 1:
                    conda_report = True

            if conda_report:
                with open(CONDA_CONTROL, 'w') as fd:
                    fd.write('0')

        return conda_report
        
    def send(self):
        global logged_in
        global session
        if not logged_in:
           logger.info('Logging in to Hopsworks....')
           Heartbeat.login()
        else:
            system_status_to_delete = []
            conda_status_to_delete = []
            try:
                logger.debug("Creating heartbeat reply...")
                disk_info = DiskInfo()
                memory_info = MemoryInfo()
                load_info = LoadInfo()
                services_list = Config().read_all_for_heartbeat()
                now = long(time.mktime(datetime.now().timetuple()))
                headers = {'content-type': 'application/json'}
                payload = {}
                payload["num-gpus"] = count_num_gpus()
                payload["host-id"] = kconfig.host_id
                payload["agent-time"] = now
                payload["load1"] = load_info.load1
                payload["load5"] = load_info.load5
                payload["load15"] = load_info.load15
                payload["disk-used"] = disk_info.used
                payload['memory-used'] = memory_info.used
                payload["services"] = services_list
                
                now_in_ms = now * 1000
                time_to_report = (now_in_ms - self._last_conda_report) > self._conda_report_interval
                if self.is_conda_gc_triggered() or time_to_report:
                    logger.debug("Triggering Conda GC")
                    envs_slice = self._conda_envs_monitor_list.slice(10)
                    if envs_slice is not None:
                        logger.debug("Investigating Anaconda envs for GC: {0}".format(envs_slice))
                        payload["conda-report"] = list(envs_slice)
                    else:
                        logger.debug("No Anaconda envs for GC")
                    self._last_conda_report = now_in_ms
                    
                commands_status = {}

                self._system_commands_status_mutex.acquire()
                system_commands_response = []
                # Append command status to response
                for k, v in self._system_commands_status.iteritems():
                    system_commands_response.append(v)
                    system_status_to_delete.append(v)

                # Remove status from local statuses state
                for command_to_delete in system_status_to_delete:
                    del self._system_commands_status[command_to_delete['id']]
                self._system_commands_status_mutex.release()
                payload["system-commands"] = system_commands_response

                self._conda_commands_status_mutex.acquire()
                conda_commands_response = []
                # Append command status to response
                for k, v in self._conda_commands_status.iteritems():
                    conda_commands_response.append(v)
                    conda_status_to_delete.append(v)

                # Remove status from local statuses state
                for command_to_delete in conda_status_to_delete:
                    del self._conda_commands_status[command_to_delete['id']]

                self._conda_commands_status_mutex.release()
                payload["conda-commands"] = conda_commands_response

                if (kconfig.private_ip != None):
                    payload["private-ip"] = kconfig.private_ip
                else:
                    payload["private-ip"] = ""

                payload["cores"] = cores
                payload["disk-capacity"] = disk_info.capacity
                payload['memory-capacity'] = memory_info.total
                logger.info("Sending heartbeat...")
                resp = session.post(kconfig.heartbeat_url, data=json.dumps(payload), headers=headers, verify=False)
                logger.info("Received heartbeat response")
                if not resp.status_code == HTTP_OK:
                    # Put back deleted statuses if command ID does not exist in order to be re-send
                    self._conda_commands_status_mutex.acquire()
                    for restore_command in conda_status_to_delete:
                        if restore_command['id'] not in self._conda_commands_status:
                            self._conda_commands_status[restore_command['id']] = restore_command
                    self._conda_commands_status_mutex.release()

                    self._system_commands_status_mutex.acquire()
                    for restore_command in system_status_to_delete:
                        if restore_command['id'] not in self._system_commands_status:
                            self._system_commands_status[restore_command['id']] = restore_command
                    self._system_commands_status_mutex.release()

                    logged_in = False
                    raise Exception('Heartbeat could not be sent (Status code: {0})'.format(resp.status_code))
                else:
                    theResponse = resp.json()
                    logger.debug("Response from heartbeat is: {0}".format(theResponse))
                    try:
                        system_commands = theResponse['system-commands']
                        for command in system_commands:
                            c = Command('SYSTEM_COMMAND', command)
                            logger.debug("Adding SYSTEM command with ID {0} and status {1} to Handler Queue".format(command['id'], command['status']))
                            commands_queue.put(c)
                            command['status'] = 'ONGOING'
                            self._system_commands_status_mutex.acquire()
                            self._system_commands_status[command['id']] = command
                            self._system_commands_status_mutex.release()

                        conda_commands = theResponse['conda-commands']
                        for command in conda_commands:
                            c = Command('CONDA_COMMAND', command)
                            logger.debug("Adding CONDA command with ID {0} and status {1} to Handler Queue".format(command['id'], command['status']))
                            commands_queue.put(c)
                            command['status'] = 'ONGOING'
                            self._conda_commands_status_mutex.acquire()
                            self._conda_commands_status[command['id']] = command
                            self._conda_commands_status_mutex.release()
                    except Exception as err:
                        logger.info("No commands to execute")
                        for data in theResponse['condaCommands']:
                            proj = data['proj']
                            conda_ongoing[proj] = False

            except Exception as err:
                logger.error("{0}. Retrying in {1} seconds...".format(err, kconfig.heartbeat_interval))
                logged_in = False

class CondaCommandsHandler:
    def __init__(self, conda_commands_status, conda_commands_status_mutex):
        self._conda_commands_status = conda_commands_status
        self._conda_commands_status_mutex = conda_commands_status_mutex

    def handle(self, command):
        global conda_ongoing
        if (command is None):
            return
        logger.debug("Handling Conda command: {0}".format(json.dumps(command, indent=2)))
        op = command['op'].upper()
        user = command['user']
        proj = command['proj']
        command_id = command['id']
        offline = ""
        logger.info("Command to execute: {0}/{1}/{2}".format(op, proj, command_id))
        if (conda_ongoing[proj] == False):
            conda_ongoing[proj] = True
            logger.info("Executing Command {0}/{1}/{2}".format(user, op, proj))
            arg = ""
            if 'arg' in command:
                arg = command['arg']
            if op == "REMOVE" or op == "CLONE" or op == "CREATE" or op == "YML" or op == "CLEAN":
                self._envOp(command, arg, offline)
            elif op == "INSTALL" or op == "UNINSTALL" or op == "UPGRADE":  # Conda package  commands (install, uninstall, upgrade)
                self._libOp(command)
            else:
                logger.error("Unkown command OP: {0} Ignoring...".format(op))
        else:
            logger.warn("Conda busy executing a command for project: {0}".format(proj))


    def _envOp(self, command, arg, offline):
        global conda_ongoing
        if not arg:
            arg=""
        user = command['user']
        command_id = command['id']
        op = command['op'].upper()
        proj = command['proj']
        install_jupyter = str(command['installJupyter']).lower()

        tempfile_fd = None
        if command['op'] == 'YML':
            tempfile_fd = tempfile.NamedTemporaryFile(suffix='.yml', delete=True)
            arg = tempfile_fd.name
            tempfile_fd.write(command['environmentYml'])
            tempfile_fd.flush()
            os.chmod(tempfile_fd.name, 0604)

        script = kconfig.bin_dir + "/anaconda_env.sh"
        logger.info("sudo {0} {1} {2} {3} {4} '{5}' {6} {7}".format(script, user, op, proj, arg, offline, kconfig.hadoop_home, install_jupyter))
        msg=""
        try:
            msg = subprocess.check_output(['sudo', script, user, op, proj, arg, offline, kconfig.hadoop_home, install_jupyter], stderr=subprocess.STDOUT)
            command['status'] = 'SUCCESS'
            command['arg'] = arg
        except subprocess.CalledProcessError as e:
            logger.info("Exception in envOp {0}".format(e.output))
            logger.info("Exception in envOp. Ret code: {0}".format(e.returncode))
            command['status'] = 'FAILED'
        finally:
            if command['op'] == 'YML' and tempfile_fd != None:
                tempfile_fd.close()
            if command_id != -1:
                self._conda_commands_status_mutex.acquire()
                logger.debug("Adding status {0} for command ID {1} - {2}".format(command['status'], command_id, command))
                self._conda_commands_status[command_id] = command
                self._conda_commands_status_mutex.release()
            conda_ongoing[proj] = False
        return msg

    def _libOp(self, command):
        global conda_ongoing
        user = command['user']
        command_id = command['id']
        op = command['op'].upper()
        proj = command['proj']
        version = command['version']
        channelUrl = command['channelUrl']
        installType = command['installType']
        lib = command['lib']
        if not channelUrl:
            channelUrl="default"
        if not version:
            version=""
        script = kconfig.bin_dir + "/conda.sh"

        try:
            command_str = "sudo {0} {1} {2} {3} {4} {5} {6} {7}".format(script, user, op, proj, channelUrl, installType, lib, version)
            logger.info("Executing libOp command {0}".format(command_str))                                            
            msg = subprocess.check_output(['sudo', script, user, op, proj, channelUrl, installType, lib, version], stderr=subprocess.STDOUT)
            logger.info("Lib op finished without error.")
            logger.info("{0}".format(msg))
            command['status'] = 'SUCCESS'
        except subprocess.CalledProcessError as e:
            logger.info("Exception in libOp {0}".format(e.output))
            logger.info("Exception in libOp. Ret code: {0}".format(e.returncode))
            command['status'] = 'FAILED'
        finally:
            conda_ongoing[proj] = False
            if command_id != -1:
                self._conda_commands_status_mutex.acquire()
                logger.debug("Adding status {0} for command ID {1} - {2}".format(command['status'], command_id, command))
                self._conda_commands_status[command_id] = command
                self._conda_commands_status_mutex.release()


class SystemCommandsHandler:
    def __init__(self, system_commands_status, system_commands_status_mutex, config_file_path, conda_envs_monitor_list):
        self._system_commands_status = system_commands_status
        self._system_commands_status_mutex = system_commands_status_mutex
        self._config_file_path = config_file_path
        self._conda_envs_monitor_list = conda_envs_monitor_list

    def handle(self, command):
        if command is None:
            return
        logger.debug("Handling System command: {0}".format(command))
        op = command['op']

        if op == 'SERVICE_KEY_ROTATION':
            self._service_key_rotation(command)
        elif op == 'CONDA_GC':
            self._conda_env_garbage_collection(command)
        else:
            logger.error("Unknown OP {0} for system command {1}".format(op, command))

    def _conda_env_garbage_collection(self, command):
        to_be_removed = json.loads(command['arguments'])
        exec_user = command['execUser']

        conda_bin = os.path.join(kconfig.conda_dir, 'bin', 'conda')
        for env in to_be_removed:
            try:
                script = os.path.join(kconfig.bin_dir, 'anaconda_env.sh')
                subprocess.check_call(['sudo', script, exec_user, 'REMOVE', env, '', '', ''])
                logger.info("Removed Anaconda environment {0}".format(env))
                self._conda_envs_monitor_list.remove(env)
            except CalledProcessError as e:
                logger.warn("Could not remove environment {0} - exit code {1}".format(env, e.returncode))
        command['status'] = 'FINISHED'
        try:
            self._system_commands_status_mutex.acquire()
            self._system_commands_status[command['id']] = command
        finally:
            self._system_commands_status_mutex.release()

    def _service_key_rotation(self, command):
        try:
            logger.debug("Calling certificate rotation script")
            csr_helper_script = os.path.join(kconfig.certs_dir, "run_csr.sh")
            subprocess.check_call(["sudo", csr_helper_script, self._config_file_path, "rotate"])
            
            command['status'] = 'FINISHED'
            logger.info("Successfully rotated service certificates")
        except CalledProcessError as e:
            logger.error("Error while calling csr script: {0}".format(e))
            command['status'] = 'FAILED'
        except Exception as e:
            logger.error("General error while rotating certificates {0}".format(e))
            command['status'] = 'FAILED'

        self._system_commands_status_mutex.acquire()
        logger.debug("Adding status {0} for command ID {1} - {2}".format(command['status'], command['id'], command))
        self._system_commands_status[command['id']] = command
        self._system_commands_status_mutex.release()


class Command:
    def __init__(self, command_type, command):
        self._command_type = command_type
        self._command = command
        if command.has_key('priority'):
            self._priority = command['priority']
        else:
            self._priority = 0

    def __cmp__(self, other):
        if self._priority < other._priority:
            return 1
        elif self._priority > other._priority:
            return -1
        else:
            if self._command['id'] < other._command['id']:
                return -1
            elif self._command['id'] > other._command['id']:
                return 1
            else:
                return 0

    def get_command_type(self):
        return self._command_type

    def get_command(self):
        return self._command

class Handler(threading.Thread):
    def __init__(self, commands_queue, systemCommandsHandler, condaCommandsHandler,
                 group=None, target=None, name=None, args=(), kwargs=None, verbose=None):
        threading.Thread.__init__(self, group=group, target=target, name=name, verbose=verbose)
        self.args = args
        self.kwargs = kwargs
        self._commands_queue = commands_queue
        self._systemCommandsHandler = systemCommandsHandler
        self._condaCommandsHandler = condaCommandsHandler
        return

    def run(self):
        logger.info("Starting commands handling thread")
        while (True):
            c = self._commands_queue.get(block=True)
            logger.debug("Handling command {0}".format(c.get_command()))
            command_type = c.get_command_type()
            command = c.get_command()

            try:
                if (command_type == 'CONDA_COMMAND'):
                    logger.info("Conda command")
                    self._condaCommandsHandler.handle(command)
                elif (command_type == 'SYSTEM_COMMAND'):
                    logger.info("System command")
                    self._systemCommandsHandler.handle(command)
            except Exception as e:
                logger.error(">>> Error while handling command {0} - Error: {1}".format(c.get_command(), e))

class Alert:
    @staticmethod
    def send(cluster, group, service, time, status):
        global session
        if not logged_in:
           logger.info('Logging in to Hopsworks....')
           Heartbeat.login()
        else:
            try:
                headers = {'content-type': 'application/json'}
                payload = {}
                payload["provider"] = "Agent"
                payload["host-id"] = kconfig.host_id
                payload["time"] = time
                payload["plugin"] = "Monitoring"
                payload["type"] = "Role"
                payload["type-instance"] = "{0}/{1}/{2}".format(cluster, group, service)
                payload["datasource"] = "Agent"
                payload["current-value"] = status
                if status == True:
                    payload["severity"] = "OK"
                    payload["message"] = "Service is running: {0}/{1}/{2}".format(cluster, group, service)
                else:
                    payload["severity"] = "FAILURE"
                    payload["message"] = "Service is not running: {0}/{1}/{2}".format(cluster, group, service)

                logger.info("Sending Alert...")
                #auth = (kconfig.server_username, kconfig.server_password)
                #            session = requests.Session()
                #            session.post(kconfig.alert_url, data=json.dumps(payload), headers=headers, auth=auth, verify=False)
                #requests.post(kconfig.alert_url, data=json.dumps(payload), headers=headers, auth=auth, verify=False)
                session.post(kconfig.alert_url, data=json.dumps(payload), headers=headers, verify=False)
            except:
                logger.error("Cannot access the REST service for alerts. Alert not sent.")


class MemoryInfo(object):
    def __init__(self):
        process = subprocess.Popen("free", shell=True, stdout=subprocess.PIPE)
        stdout_list = process.communicate()[0].split('\n')
        for line in stdout_list:
            data = line.split()
            try:
                if data[0] == "Mem:":
                    self.total = int(data[1]) * 1024
                    self.used = int(data[2]) * 1024
                    self.free = int(data[3]) * 1024
                    self.buffers = int(data[5]) * 1024
                    self.cached = int(data[6]) * 1024
                    break
            except IndexError:
                continue


class DiskInfo(object):
    def __init__(self):
        disk = os.statvfs("/")
        self.capacity = disk.f_bsize * disk.f_blocks
        self.used = disk.f_bsize * (disk.f_blocks - disk.f_bavail)


class LoadInfo(object):
    def __init__(self):
        self.load1 = os.getloadavg()[0]
        self.load5 = os.getloadavg()[1]
        self.load15 = os.getloadavg()[2]


class ExtProcess():  # external process

    @staticmethod
    def watch(cluster, group, service):
        global states
        while True:
            try:
                section = Config().section_name(cluster, group, service)
                if Service().alive(cluster,group,service) == True:
                     if (states[service]['status'] == 'Stopped'):
                       logger.info("Process started: {0}/{1}/{2}".format(cluster, group, service))
                       Service().started(cluster, group, service)
                else:
                    raise Exception("Process is not running for {0}/{1}/{2}".format(cluster, group, service))
            except:
                logger.info("Proccess.watch: Process is not running: {0}/{1}/{2}".format(cluster, group, service))
                if (states[service]['status'] == 'Started'):
                    logger.info("Process failed: {0}/{1}/{2}".format(cluster, group, service))
                    Service().failed(cluster, group, service)
            sleep(kconfig.watch_interval)

class Config():

    def section_name(self, cluster, group, service=None):
        if service == None:
            return "{0}-{1}".format(cluster, group)
        else:
            return "{0}-{1}-{2}".format(cluster, group, service)

    # select items so that the key does not contain 'file' or 'script'
    def read_all_for_heartbeat(self):
        config_mutex.acquire()
        services_list = []
        try:
            for s in services.sections():
                   item = {}
                   item['status'] = Heartbeat.serviceKey(services.get(s, "service"), 'status')
                   services_list.append(item)
                   for key, val in services.items(s):
                       if (not 'file' in key) and (not 'script' in key) and (not 'command' in key):
                           item[key] = val
                       services_list.append(item)
        finally:
            config_mutex.release()
        return services_list

    def get_section(self, section):
        config_mutex.acquire()
        items = {}
        try:
            for key, val in services.items(section):
                items[key] = val
        finally:
            config_mutex.release()
        return items

    def get(self, section, option):
        config_mutex.acquire()
        val = ""
        try:
            val = services.get(section, option)
        finally:
            config_mutex.release()
        return val

class Service:

    # need to be completed. Set the status to Initialize?
    def init(self, cluster, group, service):
        section = Config().section_name(cluster, group, service)
        script = Config().get(section, "init-script")
        try:
            p = Popen(script, shell=True, close_fds=True)
            p.wait()
            returncode = p.returncode
            if not returncode == 0:
                raise Exception("Init script returned a none-zero value")
            return True
        except Exception as err:
            logger.error(err)
            return False


    def start(self, cluster, group, service):
        script = kconfig.bin_dir + "/start-service.sh"
        try:
            p = Popen(['sudo',script,service],stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            (output,err)=p.communicate()
            returncode = p.wait()
            logger.info("{0}".format(output))
            if not returncode == 0:
                raise Exception("Start script returned a none-zero value")
            Service().started(cluster, group, service)
            # wait for the alert to get returned to Hopsworks, before returning (as this will cause a correct refresh of the service's status)
            sleep(kconfig.heartbeat_interval+1)
            return True
        except Exception as err:
            logger.error(err)
            return False

    def stop(self, cluster, group, service):
        script = kconfig.bin_dir + "/stop-service.sh"
        global states
        try:
            subprocess.check_call(['sudo', script, service], close_fds=True)  # raises exception if not returncode == 0
            now = long(time.mktime(datetime.now().timetuple()))
            states[service] = {'status':'Stopped', 'stop-time':now}
            # wait for the alert to get returned to Hopsworks, before returning (as this will cause a correct refresh of the service's status)
            Service().failed(cluster, group, service)
            sleep(kconfig.heartbeat_interval+1)
            return True
        except Exception as err:
            logger.error(err)
            return False

    def restart(self, cluster, group, service):
        script = kconfig.bin_dir + "/restart-service.sh"
        try:
            p = Popen(['sudo',script,service], close_fds=True)
            p.wait()
            returncode = p.returncode
            if not returncode == 0:
                raise Exception("Restart script returned a none-zero value")
            Service().started(cluster, group, service)
            # wait for the alert to get returned to Hopsworks, before returning (as this will cause a correct refresh of the service's status)
            sleep(kconfig.heartbeat_interval)
            return True
        except Exception as err:
            logger.error(err)
            return False

    def alive(self, cluster, group, service):
        script = kconfig.bin_dir + "/status-service.sh"
        try:
            p = Popen(['sudo',script,service], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            if (verbose == True):
                with p.stdout:
                    for line in iter(p.stdout.readline, b''):
                        logger.info("{0}".format(line))
            p.wait()
            if not p.returncode == 0:
                return False
        except Exception as err:
            logger.error(err)
            return False
        return True

    def failed(self, cluster, group, service):
        global states
        now = long(time.mktime(datetime.now().timetuple()))
        states[service] = {'status':'Stopped', 'start-time':now}
        Alert.send(cluster, group, service, now, False)

    def started(self, cluster, group, service):
        global states
        now = long(time.mktime(datetime.now().timetuple()))
        states[service] = {'status':'Started', 'start-time':now}
        Alert.send(cluster, group, service, now, True)


class MySQLConnector():
    @staticmethod
    def read(database, table):
        try:
            db = MySQLdb.connect(unix_socket=kconfig.mysql_socket, db=database)
            cur = db.cursor()
            query = "SELECT * FROM {0}".format(table)
            cur.execute(query)
            return json.dumps(cur.fetchall())
        except Exception as err:
            logger.error("Could not access {0} table from {1}: {2}".format(table, database, err))
            return json.dumps(["Error", "Error: Could not access {0} table from {1}.".format(table, database)])

    @staticmethod
    def read_ndbinfo(table):
        return MySQLConnector.read("ndbinfo", table)


class CommandHandler():

    def response(self, code, msg):
        resp = HTTPResponse(status=code, output=msg)
        logger.info("{0}".format(resp))
        return resp

    def init(self, cluster, group, service):
        section = Config().section_name(cluster, group, service)
        if not services.has_section(section):
            return CommandHandler().response(400, 'Service not installed.')
        else:
            if Service().init(cluster, group, service) == True:
                return CommandHandler().response(200, 'Service initialized.')
            else:
                return CommandHandler().response(400, 'Error: Cannot initialize the service.')

    def start(self, cluster, group, service):
        global states
        section = Config().section_name(cluster, group, service)
        if not services.has_section(section):
            return CommandHandler().response(400, 'Service not installed.')
        elif states[service]['status'] == 'Started':
            return CommandHandler().response(400, 'Service already started.')
        else:
            res = Service().start(cluster, group, service)
            if res == False:
                return CommandHandler().response(400, 'Error: Cannot start the service.')
            else:
                return CommandHandler().response(200, "Service started.")

    def stop(self, cluster, group, service):
        global states
        section = Config().section_name(cluster, group, service)
        if not services.has_section(section):
            return CommandHandler().response(400, 'Service not installed.')
        elif not states[service]['status'] == 'Started':
            return CommandHandler().response(400, 'Service is not running.')
        else:
            if Service().stop(cluster, group, service) == True:
                return CommandHandler().response(200, 'Service stopped.')
            else:
                return CommandHandler().response(400, 'Error: Cannot stop the service.')

    def restart(self, cluster, group, service):
        section = Config().section_name(cluster, group, service)
        if not services.has_section(section):
            return CommandHandler().response(400, 'Service not installed.')
        else:
            res = Service().restart(cluster, group, service)
            if res == False:
                return CommandHandler().response(400, 'Error: Cannot restart the service.')
            else:
                return CommandHandler().response(200, "Service started.")

    def read_log(self, cluster, group, service, lines):
        try:
            lines = int(lines)
            if service == None:
                section = Config().section_name(cluster, group)
            else:
                section = Config().section_name(cluster, group, service)
            log_file_name = Config().get(section, "stdout-file")
            log = Util().tail(log_file_name, lines)
            return CommandHandler().response(200, log)

        except Exception as err:
            logger.error(err)
            return CommandHandler().response(400, "Cannot read file.")

    def read_agent_log(self, lines):
        try:
            log = Util().tail(kconfig.agent_log_file, lines)
            return CommandHandler().response(200, log)

        except Exception as err:
            logger.error(err)
            return CommandHandler().response(400, "Cannot read file.")

    def read_config(self, cluster, group, service):
        try:
            section = Config().section_name(cluster, group, service)
            config_file_name = Config().get(section, "config-file")
            with open(config_file_name) as config_file:
                conf = "".join(str(x) for x in (list(config_file)))
            return CommandHandler().response(200, conf)

        except Exception as err:
            logger.error(err)
            return CommandHandler().response(400, "Cannot read file.")

    def info(self, cluster, group, service):
        try:
            section = Config().section_name(cluster, group, service)
            resp = json.dumps(Config().get_section(section))
            return CommandHandler().response(200, resp)

        except Exception as err:
            logger.error(err)
            return CommandHandler().response(400, "Cannot read file.")

    def read_ndbinfo(self, table):
        res = MySQLConnector.read_ndbinfo(table)
        return CommandHandler().response(200, res)

    def execute(self, cluster, group, service, command, params):
        try:
            if service == None:
                section = Config().section_name(cluster, group)
            else:
                section = Config().section_name(cluster, group, service)
            script = Config().get(section, "command-script")
            logger.info("Script name executing is: {0}".format(script))
            env = Config().get(section, "command-env")
            command = env + " " + script + " " + params
            command = re.sub(r'([\"])', r'\\\1', command)
            as_user = Config().get(section, "command-user")
# TODO: could check if as_user == "root" or as_user == "sudo" here...
            if not as_user:
                logger.warn("No user supplied to execute command: {0}".format(command))
                raise Exception("Not allowed execute command as user: {0}".format(as_user))
            if as_user:
                command = "su - " + as_user + " -c \"" + command + "\""
# TODO: shell=True is insecure when using untrusted input
# as an attacker can input "hdfs dfs -ls / ; rm -rf /"
            p = Popen(command , shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            out, err = p.communicate()
            return CommandHandler().response(200, out)
        except Exception as err:
            logger.error(err)
            return CommandHandler().response(400, "Could not execute.")


    def refresh(self):
        Heartbeat.send(False);
        return CommandHandler().response(200, "OK")


class Authentication():
    def check(self):
        result = False
        try:
            inPassword = request.params['password']
            if (inPassword == kconfig.agent_password):
                return True
        except Exception:
            result = False

        if result == False:
            logger.info("Authentication failed: Invalid password: {0}".format(inPassword))
        return result

    def failed(self):
        return HTTPResponse(status=400, output="Invalid password")


class SSLCherryPy(ServerAdapter):
    def run(self, handler):
        server = wsgi.Server((self.host, self.port), handler)
        server.ssl_adapter = BuiltinSSLAdapter(kconfig.certificate_file, kconfig.key_file)
        try:
            server.start()
        finally:
            server.stop()


if __name__ == '__main__':

    parser = argparse.ArgumentParser(description='Hops nodes administration agent')
    parser.add_argument('-v', '--verbose', action='store_true')
    parser.add_argument('-c', '--config', default='config.ini', help='Path to configuration file')

    args = parser.parse_args()
    
    verbose = args.verbose

    global kconfig
    kconfig = KConfig(args.config)
    kconfig.read_conf()

    setupLogging(kconfig)
    readServicesFile()
        
    agent_pid = str(os.getpid())
    file(kconfig.agent_pidfile, 'w').write(agent_pid)
    logger.info("Hops Kagent PID: {0}".format(agent_pid))

    interval_parser = IntervalParser()
    conda_report_interval = interval_parser.get_interval_in_ms(kconfig.conda_gc_interval)
    conda_envs_monitor_list = kagent_utils.ConcurrentCircularLinkedList()
    watcher_action = kagent_utils.CondaEnvsWatcherAction(conda_envs_monitor_list, kconfig)
    watcher_interval = int(interval_parser.get_interval_in_s(kconfig.conda_gc_interval) / 2)
    # Default interval to 1 second. We don't want the watcher to spin like crazy
    conda_envs_watcher = kagent_utils.Watcher(watcher_action, max(1, watcher_interval), name="conda_gc_watcher")
    conda_envs_watcher.setDaemon(True)
    conda_envs_watcher.start()
    
    # Heartbeat, process watch (alerts) and REST API are available after the agent registers successfully
    commands_queue = Queue.PriorityQueue(maxsize=100)

    system_commands_status = {}
    system_commands_status_mutex = Lock()
    config_file_path = os.path.abspath(args.config)
    system_commands_handler = SystemCommandsHandler(system_commands_status, system_commands_status_mutex,
                                                    config_file_path, conda_envs_monitor_list)

    conda_commands_status = {}
    conda_commands_status_mutex = Lock()
    conda_commands_handler = CondaCommandsHandler(conda_commands_status, conda_commands_status_mutex)

    commands_handler = Handler(commands_queue, system_commands_handler, conda_commands_handler)
    commands_handler.setDaemon(True)
    commands_handler.start()

    hb_thread = threading.Thread(target=Heartbeat, args=(commands_queue, system_commands_status, system_commands_status_mutex,
                                                         conda_commands_status, conda_commands_status_mutex, conda_report_interval,
                                                         conda_envs_monitor_list))
    hb_thread.setDaemon(True)
    hb_thread.start()

    for s in services.sections():
        cluster = Config().get(s, "cluster")
        group = Config().get(s, "group")
        if services.has_option(s, "service"):
            service = Config().get(s, "service")
            my_thread = threading.Thread(target=ExtProcess.watch, args=(cluster, group, service))
            my_thread.setDaemon(True)
            my_thread.start()
        else:
            logger.info("Not watching {0}/{1}".format(cluster, group))        

# The REST code uses a CherryPy webserver, but Bottle for the REST endpoints
# WSGI server for SSL
# For a a tutorial on the REST code below, see http://bottlepy.org/docs/dev/tutorial.html

    server_names['sslcherrypy'] = SSLCherryPy
    app = Bottle()
    @get('/ping')
    def ping():
        logger.info('Incoming REST Request:  GET /ping')
        return "Hops-Agent: Pong"

    @get('/do/<cluster>/<group>/<service>/<command>')
    def do(cluster, group, service, command):
        logger.info('Incoming REST Request:  GET /do/{0}/{1}/{2}/{3}'.format(cluster, group, service, command))
        if not Authentication().check():
            return Authentication().failed()
        section = Config().section_name(cluster, group, service)
        logger.info("Section is {0}".format(section))
        if not services.has_section(section):
            logger.error("Couldn't find command {0} in {1}/{2} in section {3}".format(command, group, service, section))
            return HTTPResponse(status=400, output='Invalid command.')

        groupInServicesFile = Config().get(section, "group")
        serviceInServicesFile = Config().get(section, "service")
        commandInServicesFile = Config().get(section, "{0}-script".format(command))

        if (not service == groupInServicesFile) or (not service == serviceInServicesFile) or (not commandInServicesFile):
            logger.error("Couldn't find command {0} in {1}/{2}".format(command, group, service))
            return HTTPResponse(status=400, output='Invalid command.')

        if command == "start":
            return CommandHandler().start(cluster, group, service);
        elif command == "stop":
            return CommandHandler().stop(cluster, group, service);
        elif command == "init":
            return CommandHandler().init(cluster, group, service);
        else:
            return HTTPResponse(status=400, output='Invalid command.')

    @get('/restartService/<cluster>/<group>/<service>')
    def restartService(cluster, group, service):
        logger.info('Incoming REST Request:  GET /restartService/{0}/{1}/{2}'.format(cluster, group, service))
        if not Authentication().check():
            return Authentication().failed()

        if not services.has_section(Config().section_name(cluster, group, service)):
            return HTTPResponse(status=400, output='Cluster/Group/Service not available.')

        return CommandHandler().restart(cluster, group, service);

    @get('/startService/<cluster>/<group>/<service>')
    def startService(cluster, group, service):
        logger.info('Incoming REST Request:  GET /startService/{0}/{1}/{2}'.format(cluster, group, service))
        if not Authentication().check():
            return Authentication().failed()

        if not services.has_section(Config().section_name(cluster, group, service)):
            return HTTPResponse(status=400, output='Cluster/Group/Service not available.')

        return CommandHandler().start(cluster, group, service);

    @get('/stopService/<cluster>/<group>/<service>')
    def stopService(cluster, group, service):
        logger.info('Incoming REST Request:  GET /stopService/{0}/{1}/{2}'.format(cluster, group, service))
        if not Authentication().check():
            return Authentication().failed()

        if not services.has_section(Config().section_name(cluster, group, service)):
            return HTTPResponse(status=400, output='Cluster/Group/Service not available.')

        return CommandHandler().stop(cluster, group, service);

    @get('/log/<cluster>/<group>/<service>/<lines>')
    def log(cluster, group, service, lines):
        logger.info('Incoming REST Request:  GET /log/{0}/{1}/{2}/{3}'.format(cluster, group, service, lines))
        if not Authentication().check():
            return Authentication().failed()

        if not services.has_section(Config().section_name(cluster, group, service)):
            return HTTPResponse(status=400, output='Cluster/Group/Service not available.')

        return CommandHandler().read_log(cluster, group, service, lines);


    @get('/log/<cluster>/<group>/<lines>')
    def log(cluster, group, lines):
        logger.info('Incoming REST Request:  GET /log/{0}/{1}'.format(cluster, group))
        if not Authentication().check():
            return Authentication().failed()

        if not services.has_section(Config().section_name(cluster, group)):
            return HTTPResponse(status=400, output='Cluster/Group not available.')

        return CommandHandler().read_log(cluster, group, None, lines);


    @get('/agentlog/<lines:int>')
    def agentlog(lines):
        logger.info('Incoming REST Request:  GET /agentlog/{0}'.format(lines))
        if not Authentication().check():
            return Authentication().failed()

        return CommandHandler().read_agent_log(lines);

    @get('/config/<cluster>/<group>/<service>')
    def config(cluster, group, service):
        logger.info('Incoming REST Request:  GET /log/{0}/{1}/{2}'.format(cluster, group, service))
        if not Authentication().check():
            return Authentication().failed()

        if not services.has_section(Config().section_name(cluster, group, service)):
            return HTTPResponse(status=400, output='Cluster/Group/Service not available.')

        return CommandHandler().read_config(cluster, group, service);

    @get('/info/<cluster>/<group>/<service>')
    def info(cluster, group, service):
        logger.info('Incoming REST Request:  GET /status/{0}/{1}/{2}'.format(cluster, group, service))
        if not Authentication().check():
            return Authentication().failed()

        if not services.has_section(Config().section_name(cluster, group, service)):
            return HTTPResponse(status=400, output='Cluster/Group/Service not available.')

        return CommandHandler().info(cluster, group, service);

    @get('/refresh')  # request heartbeat
    def refresh():
        logger.info('Incoming REST Request:  GET /refresh')
        if not Authentication().check():
            return Authentication().failed()

        return CommandHandler().refresh();

    @get('/mysql/ndbinfo/<table>')
    def mysql_read(table):
        logger.info('Incoming REST Request:  GET /mysql/ndbinfo/{0}'.format(table))
        if not Authentication().check():
            return Authentication().failed()

        return CommandHandler().read_ndbinfo(table)

    @post('/execute/<state>/<cluster>/<group>/<service>/<command>')
    def execute_hdfs(state, cluster, group, service, command):
        logger.info('Incoming REST Request:  POST /execute/{0}/{1}/{2}/{3}/{4}'.format(state, cluster, group, service, command))
        if not Authentication().check():
            return Authentication().failed()
        if request.body.readlines():
            params =  request.body.readlines()[0]
        else:
            params = ""
        if state == "run" :
            if service == "-":
                return CommandHandler().execute(cluster, group, None, command, params);
            else:
                return CommandHandler().execute(cluster, group, service, command, params);
        return CommandHandler().response(404, "Error")



    @get('/conda/<user>/<command_id>/<op>/<proj>/<lib>')
    def conda(user,command_id,op,proj,lib):
        logger.info('Incoming REST Request:  GET /conda/{0}/{1}/{2}'.format(op, proj, lib))
        if not Authentication().check():
            return Authentication().failed()
        channelurl = request.params['channelurl']
        version = request.params['version']
        try:
            msg = Conda().conda(user,command_id, op, proj, channelurl, lib, version)
            resp = HTTPResponse(status=HTTP_OK, output=msg)
            logger.info("{0}".format(resp))
            return resp
        except Exception as err:
            logger.error("{0}".format(err))
            return CommandHandler().response(400, "Error")

    # Normal client sets 'channel' to 'defaults' for http://conda.anaconda.org/ or 'system' to get system packages
    # curl -k -X GET https://10.0.2.15:8090/create/project?password=blah
    # curl -k -X GET https://10.0.2.15:8090/clone/projectSrc/projectDest?password=blah
    @get('/anaconda/<user>/<command_id>/<op>/<proj>/<arg>')
    def anaconda(user, command_id, op, proj, arg):
        logger.info('Incoming REST Request:  GET /anaconda/{0}/{1}/{2}'.format(user, op, proj))
        if not Authentication().check():
            return Authentication().failed()
        # Blocking REST call here
        arg = "default"
        if (op == "clone"):
            arg = request.params['srcproj']
        try:
            msg = Conda()._envOp(user, command_id, op, proj, arg, "")
            resp = HTTPResponse(status=HTTP_OK, output=msg)
            logger.info("{0}".format(resp))
            return resp
        except Exception as err:
            logger.error("{0}".format(err))
            return CommandHandler().response(400, "Error")

    logger.info("RESTful service started.")
    run(host='0.0.0.0', port=kconfig.rest_port, server='sslcherrypy')

