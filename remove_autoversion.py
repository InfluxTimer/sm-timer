# Remove autoversion.inc file from builds
# We don't want modified plugins to have our build number
import os


def main():
    print('Removing autoversion.inc files...')

    builds = ['full', 'bhop', 'bhoplite', 'surf', 'deathrun']

    for b in builds:
        try:
            os.remove('builds/' + b + '/addons/sourcemod/scripting/include/influx/autoversion.inc')
        except Exception as e:
            print('Failed to remove autoversion.inc!')
            print(e)


if __name__ == '__main__':
    main()

