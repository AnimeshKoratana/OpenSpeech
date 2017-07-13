from kafka import KafkaConsumer
import argparse
import subprocess
import client
import RAKE
import json
import os
import sys
from pymongo import MongoClient
from kafka.structs import OffsetAndMetadata

def main():
    os.system('sh /opt/run-task.sh');
    parser = argparse.ArgumentParser(description='Runs the Kafka Client to Transcribe Videos and Store the Output in MongoDB')
    parser.add_argument('--trans_server', type=str, help='Location of Kafka Producer',
                        default="ws://localhost:80/client/ws/speech")
    parser.add_argument('--kafka', type=str, help='Location of Kafka Producer', default="ec2-52-30-104-224.eu-west-1.compute.amazonaws.com")
    parser.add_argument('--mp3_dir', type=str, help='Default is /content/audio', default="/mnt/s3/content/audio/")
    parser.add_argument('--mp4_dir', type=str, help='Default is /content/video',  default="/mnt/s3/content/video/")
    parser.add_argument('--debug', type=str, help='Just run on one input file')


    args = parser.parse_args()

    rake = RAKE.Rake('SmartStoplist.txt');

    subprocess.call("sh start.sh -y /opt/models/english_nnet2.yaml", shell=True)

    if not args.debug:
        uri = "mongodb://"+os.environ['MONGO_USER']+":"+os.environ['MONGO_PASS']+"@"+os.environ['MONGO_HOST']+"/"+os.environ['MONGO_DB']+"?authMechanism=SCRAM-SHA-1"
        mongoclient = MongoClient(uri)
        db=mongoclient[os.environ['MONGO_DB']]
        consumer = KafkaConsumer( bootstrap_servers=args.kafka, auto_offset_reset='earliest', group_id='media-transcription-group', max_poll_records=1, enable_auto_commit=False)
        while (True):
                consumer.subscribe(["media-transcription"])
                records = consumer.poll(60000000,1)
                consumer.commit()
                consumer.unsubscribe()
                print records
                for rec in records:
                        message = records[rec][0]
                        #consumer.commit({rec: OffsetAndMetadata(message.offset, None)})
                        print ("-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
                        file_path = get_file_path(message.value, mp4dir=args.mp4_dir, mp3dir=args.mp3_dir)
                        try:
                                if not file_path.__eq__("donothing"):
                                        output = run_pipeline(file_path=file_path, rake=rake, trans_uri=args.trans_server)
                                        mediafile=get_file_name(message.value)
                                        text=json.loads(output)
                                        db.Content.update({"mediaFileName" : mediafile},{"$set": {"transcriptedText" : text['transcription'], "transcription": output}}, upsert=False)
                                        subprocess.call("python /opt/publish.py "+mediafile, shell=True)
                                        print("Finished transcription and update for "+message.value+" ..")
                                else:
                                        print("create-transcription tag was not found in the input message...skipping")
                        except:
                                print ("Error on " + message.value + " ... Moving On")
                                print sys.exc_info()

                        print ("-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
    else:
        run_pipeline(args.debug, rake=rake, trans_uri=args.trans_server)

def run_pipeline(file_path, rake, trans_uri):
    print("Downsampling File and Cleaning Up Noise" + file_path)
    cleaned_file = downsample_audio(file_path)
    transcription = client.getTranscription(cleaned_file, uri=trans_uri)
    print("Done with transcription")
    #proc = subprocess.Popen(["python /opt/client.py -u="+trans_uri+" "+cleaned_file], stdout=subprocess.PIPE, shell=True)
    #(transcription, err) = proc.communicate()
    write_transcription_file(transcription)
    keywords = rake.run(transcription)
    time_aligned = list(align_audio()['fragments'])
    final_json = createJSON(filepath=file_path, transcription=transcription, keywords=keywords, words=time_aligned)
    clean_for_next_iter()
    print "keywords done"
    return final_json


def createJSON(filepath, transcription, keywords, words):
    finaljson = {}
    finaljson['filepath'] = filepath
    finaljson['transcription'] = transcription
    finaljson['timealigned'] = words
    finaljson['keywords'] = keywords
    return json.dumps(finaljson)


def write_transcription_file(transcription, path='/tmp/openspeech/transcription.txt', words_per_line = 3):
    words = transcription.split(' ')
    with open(path, 'w') as writer:
        for idx, word in enumerate(words):
            if idx.__mod__(words_per_line) == 0 and idx.__nonzero__():
                writer.write('\n')
            writer.write(str(word + " "))


def align_audio(path_to_audio = '/tmp/openspeech/transformed.wav', path_to_transcription = '/tmp/openspeech/transcription.txt'):
    align_command = ['python', '-m', 'aeneas.tools.execute_task', path_to_audio, path_to_transcription, "task_language=eng|is_text_type=plain|os_task_file_format=json", '/tmp/openspeech/sonnet.json']
    subprocess.Popen(align_command).wait()
    with open('/tmp/openspeech/sonnet.json') as reader:
        data = json.loads(reader.read())
        reader.close()
        return data


def clean_for_next_iter():
    subprocess.call("rm -rf /tmp/openspeech/*", shell=True)


def downsample_audio(path_to_file):
    #subprocess.call("rm -rf /tmp/openspeech/transformed.wav", shell=True)
    downsample_command = ['ffmpeg' , '-i' , path_to_file, '-qscale', '0', '-acodec', 'pcm_s16le', '-ac', '1', '-ar', '16000', '/tmp/openspeech/transformed.wav']
    subprocess.Popen(downsample_command).wait()
    return "/tmp/openspeech/transformed.wav"

def get_file_path(input_message, mp4dir, mp3dir):
    if str(input_message).__contains__("create-transcription"):
        path = str(str(input_message).split("##")[1])
        fullpath = ""
        if (path.endswith('.mp4') or path.endswith('.m4v')):
            fullpath=mp4dir
        elif path.endswith('.mp3'):
            fullpath=mp3dir
        fullpath+=path
        return fullpath
    else:
        return "donothing"

def get_file_name(input_message):
    if str(input_message).__contains__("create-transcription"):
        path = str(str(input_message).split("##")[1])
        return path
    else:
        return "donothing"

if __name__ == '__main__':
    main()