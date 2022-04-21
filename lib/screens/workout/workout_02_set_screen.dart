import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:npng/screens/workout/workout_03_timer_screen.dart';
import 'package:npng/data/models/workout_provider.dart';
import 'package:npng/widgets/multiplatform_widgets.dart';
import 'package:provider/provider.dart';
import 'package:npng/generated/l10n.dart';
import 'package:npng/config.dart';
import 'package:steps_indicator/steps_indicator.dart';

class WorkoutSetScreen extends StatelessWidget {
  static const String id = '/set';
  const WorkoutSetScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MpScaffold(
      appBar: MpAppBar(
        title: Consumer<WorkoutProvider>(
          builder: (context, wk, child) {
            return Text(wk.excersises[wk.currentExcersise].name);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Text(S.of(context).sets),
            SizedBox(
              height: 80.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  MpFlatButton(
                    child: const Icon(Icons.arrow_back_ios_rounded),
                    onPressed: () =>
                        Provider.of<WorkoutProvider>(context, listen: false)
                            .manualRemoveOneSet(),
                  ),
                  Consumer<WorkoutProvider>(
                    builder: (context, workout, child) {
                      int mSet = workout.maxSet + 1;
                      double maxLineLength =
                          MediaQuery.of(context).size.width * 0.65;
                      double linelength = maxLineLength;
                      if (mSet > 1) {
                        linelength = maxLineLength / (mSet - 1) -
                            14 / (mSet - 1) -
                            10 / (mSet - 1) * mSet;
                        if (linelength < 0) {
                          linelength = 0;
                        }
                      }
                      return StepsIndicator(
                        lineLength: linelength,
                        selectedStep: workout.currentSet,
                        nbSteps: workout.maxSet + 1,
                        doneLineColor: (isApple)
                            ? CupertinoTheme.of(context).primaryColor
                            : Theme.of(context).colorScheme.secondary,
                        undoneLineColor: (isApple)
                            ? CupertinoTheme.of(context).primaryColor
                            : Theme.of(context).colorScheme.secondary,
                      );
                    },
                  ),
                  MpFlatButton(
                    child: const Icon(Icons.arrow_forward_ios_rounded),
                    onPressed: () =>
                        Provider.of<WorkoutProvider>(context, listen: false)
                            .manualAddOneSet(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<WorkoutProvider>(
                builder: (context, workout, child) {
                  return CurrentSetWidget(
                    setNumber: workout.currentSet,
                  );
                },
              ),
            ),
            MpButton(
              label: S.of(context).restButton,
              onPressed: () {
                Navigator.pushNamed(context, TimerScreen.id);
                // .whenComplete(
                //     () => workout.incCurrentSet());
              },
            ),
            const SizedBox(
              height: 40.0,
            ),
          ],
        ),
      ),
    );
  }
}

class CurrentSetWidget extends StatelessWidget {
  const CurrentSetWidget({
    Key? key,
    required this.setNumber,
  }) : super(key: key);

  final int setNumber;

  @override
  Widget build(BuildContext context) {
    WorkoutProvider workout =
        Provider.of<WorkoutProvider>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(S.of(context).weight),
        MpChangeDoubleFieldExtended(
          value: workout
              .excersises[workout.currentExcersise].sets[setNumber].weight,
          increaseCallback: () => workout.incWeight025(
              excersiseNumber: workout.currentExcersise, setNumber: setNumber),
          decreaseCallback: () => workout.decWeight025(
              excersiseNumber: workout.currentExcersise, setNumber: setNumber),
          increaseCallbackFast: () => workout.incWeight5(
              excersiseNumber: workout.currentExcersise, setNumber: setNumber),
          decreaseCallbackFast: () => workout.decWeight5(
              excersiseNumber: workout.currentExcersise, setNumber: setNumber),
        ),
        Text(S.of(context).repeats),
        MpChangeIntField(
          value: workout
              .excersises[workout.currentExcersise].sets[setNumber].repeats,
          decreaseCallback: () => workout.decRepeats(
              excersiseNumber: workout.currentExcersise, setNumber: setNumber),
          increaseCallback: () => workout.incRepeats(
              excersiseNumber: workout.currentExcersise, setNumber: setNumber),
        ),
      ],
    );
  }
}
