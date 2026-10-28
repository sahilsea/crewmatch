import mongoose from 'mongoose';
import { MAX_CREW_SIZE } from '../config/options.js';

const { Schema } = mongoose;

const crewSchema = new Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 50 },
    createdBy: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    members: {
      type: [{ type: Schema.Types.ObjectId, ref: 'User' }],
      validate: [(v) => v.length <= MAX_CREW_SIZE, `A crew has at most ${MAX_CREW_SIZE} members`],
    },
    // Filled later by the AI idea agent.
    ideas: [
      {
        _id: false,
        title: String,
        pitch: String,
        whyThisCrew: String,
        whoBuildsWhat: [String],
      },
    ],
  },
  { timestamps: true }
);

export default mongoose.model('Crew', crewSchema);
