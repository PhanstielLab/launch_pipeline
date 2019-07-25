
import argparse

parser = argparse.ArgumentParser(description="samplename.")
parser.add_argument("--samplename", action = "store", type = str, dest="samplename", help = "samplename.", required = True)
args = parser.parse_args()
samplename = args.samplename

samplename_sections = samplename.split("_")
proj_name = samplename_sections[0]
print(proj_name)
