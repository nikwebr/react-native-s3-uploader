import React, { useEffect, useRef } from 'react';
import { View, StyleSheet, Animated } from 'react-native';

type ProgressBarProps = {
  progress: number;
  height?: number;
  backgroundColor?: string;
  progressColor?: string;
};

const ProgressBar: React.FC<ProgressBarProps> = ({
  progress,
  height = 10,
  backgroundColor = '#e0e0e0',
  progressColor = '#3b82f6',
}) => {
  const animation = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.timing(animation, {
      toValue: Math.max(0, Math.min(progress, 1)),
      duration: 500,
      useNativeDriver: false,
    }).start();
  }, [progress, animation]);

  const widthInterpolated = animation.interpolate({
    inputRange: [0, 1],
    outputRange: ['0%', '100%'],
  });

  return (
    <View style={[styles.container, { height, backgroundColor }]}>
      <Animated.View
        style={[
          styles.progress,
          { backgroundColor: progressColor, width: widthInterpolated },
        ]}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    width: '100%',
    borderRadius: 5,
    overflow: 'hidden',
  },
  progress: {
    height: '100%',
  },
});

export default ProgressBar;
