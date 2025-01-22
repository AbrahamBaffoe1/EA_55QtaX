import React from 'react';
import { Box, Typography } from '@mui/material';

const NewsPreview = ({ title, summary }) => {
  return (
    <Box sx={{ mb: 2 }}>
      <Typography variant="h6" gutterBottom>
        {title}
      </Typography>
      <Typography variant="body2">
        {summary}
      </Typography>
    </Box>
  );
};

export default NewsPreview;
